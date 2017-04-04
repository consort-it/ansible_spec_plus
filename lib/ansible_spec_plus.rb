require_relative '../lib/helpers/log'
require_relative '../lib/ansiblespec_helper'

require 'rake'
require 'rspec/core/rake_task'
require 'yaml'
require 'ansible_spec'
require 'pp'
require 'json'

class AnsibleSpecPlus
  include Helpers::Log

  BASE_DIR = ENV['BASE_DIR']

  ##################
  # COMMON METHODS #
  ##################

  def run(options)
    list_all_specs if options[:list] == true

    list_role_specs if options[:list_rolespec] == true
    list_host_specs if options[:list_hostspec] == true
    list_playbook_specs if options[:list_playbookspec] == true

    run_role_spec(options[:run_rolespec]) if options[:run_rolespec]
    run_host_spec(options[:run_hostspec]) if options[:run_hostspec]
    run_playbook_spec(options[:run_playbookspec]) if options[:run_playbookspec]
  end

  def list_all_specs
    list_role_specs
    list_host_specs
    list_playbook_specs
  end

  def check_for_specs_in_file(file)
    File.readlines(file).grep(/describe\s{1}/).any?
  end

  def analyze_resources(resources)
    analyzed_resources = []

    resources.each do |resource|
      resource_type = nil

      resource.keys.each do |key|
        resource_type = key if KNOWN_RESOURCES.include?(key)
      end

      if resource_type.nil?
        log.warn "Unknown resource: #{resource}"
        next
      end

      skip = false

      if resource.values[1].respond_to?(:each)
        resource.values[1].each do |key, value|
          skip = true if value =~ /\{\{/
        end
      else
        skip = true if resource.values[1] =~ /\{\{/
      end

      if skip == true
        log.warn "Don't know how to deal with '{{ }}' syntax: #{resource}"
        next
      end

      if resource_type == 'file' || resource_type == 'template'
        resource_type = 'File'
        if resource.values[1].respond_to?(:each)
          target = resource.values[1].select { |i| i =~ /path|dest/ }
          resource_name = target.values[0]
        else
          target = resource.values[1].split(" ").select { |i| i =~ /path|dest/ }
          resource_name = target.first.gsub(/.*=/,'')
        end
      elsif resource_type == 'docker_container'
        resource_type = 'Docker container'
        resource_name = resource.values[1]['name']
      elsif resource_type == 'docker_image'
        resource_type = 'Docker image'
        resource_name = resource.values[1]['name']
      elsif resource_type == 'service'
        resource_type = 'Service'
        if resource.values[1].respond_to?(:each)
          resource_name = resource.values[1]['name']
        else
          resource_name = resource.values[1].split(" ")[0].gsub(/.*=/,'')
        end
      elsif resource_type =~ /apt|pip|gem/
        if resource_type == 'apt'
          log.warn "Unknown resource: #{resource}"
          next unless resource['apt'].include?('name')
        end

        resource_type = 'Package'
        resource.each do |item|
          next unless item[0] =~ /apt|pip|gem/

          resource_name = item[1]['name']
        end
      else
        next
      end

      analyzed_resources << "#{resource_type} \"#{resource_name}\""
    end

    return analyzed_resources
  end

  def get_hosts_from_vai_host_file
    inventory_hosts = []
    hosts_with_vagrant_vars = {}

    Dir.chdir(BASE_DIR) do
      begin
        File.open('hosts', 'r') do |file|
          file.each_line do |line|
            pattern = /^#.*|^$\n|^\[.*|^\r\n?/
            next if line =~ pattern
            inventory_hosts << line
          end
        end
      rescue => e
        log.error "hosts file doesn't exist: #{e}"
      end
    end

    inventory_hosts.each do |line|
      hostname = line.split(' ').first

      parts = line.match(/\s.*/).to_s.split(' ')

      vars = {}
      vars['name'] = hostname
      parts.each do |part|
        key = part.gsub(/=.*/,'')
        value = part.gsub(/.*=/,'').gsub(/'|"/,'')
        vars["#{key}"] = value
      end

      hosts_with_vagrant_vars[hostname] = [vars]
    end

    return hosts_with_vagrant_vars
  end

  def print_rounded_role_coverage(all_resources, differences)
    if all_resources.count == 0
      return "0%"
    else
      "#{((all_resources - differences).count.to_f / all_resources.count.to_f * 100.0).round}%"
    end
  end

  def calculate_coverage(type, name)
    Dir.chdir(BASE_DIR) do
      json_report = File.read('report.json')
      parsed_report = JSON.parse(json_report)

      case type
      when 'role'
        all_known_resources = analyze_resources(load_role_resources(name))
      when 'host'
        all_known_resources = analyze_resources(load_host_resources(name))
      when 'playbook'
        all_known_resources = analyze_resources(load_playbook_resources(name))
      else
        raise "Unknow type '#{type}'. Should be either role, host or playbook."
      end

      tested_resources = []

      parsed_report['examples'].each do |example|
        tested_resources << example['full_description'].gsub(/"\s{1}.*/,'"')
      end

      tested_resources = tested_resources.uniq

      differences = []

      all_known_resources.each do |resource|
        differences << resource if ! tested_resources.include?(resource)
      end

      puts "Total resources: #{all_known_resources.count}"
      puts "Touched resources: #{(all_known_resources - differences).count}"
      puts "Resource coverage: #{print_rounded_role_coverage(all_known_resources, differences)}"

      if differences.count > 0
        puts "\nUncovered resources:"
        differences.each do |item|
          puts "- #{item}"
        end
      end
    end
  end

  ################
  # ROLE METHODS #
  ################

  def list_role_specs
    get_roles_with_specs.each do |role|
      command = "asp rolespec #{role}"
      description = "# run role specs for #{role}"

      puts "#{command} #{description.rjust(40)}"
    end
  end

  def run_role_spec(role)
    if check_role_directory_available(role) && check_role_specs_available(role)
      create_role_rake_task(role)

      Dir.chdir(BASE_DIR) do
        Rake.application["#{role}"].invoke()
      end

      calculate_coverage('role', role)
    end
  end

  def get_all_roles
    all_roles = []

    Dir.chdir(BASE_DIR) do
      Dir.glob("roles/*").each do |role|
        all_roles << File.basename(role)
      end
    end

    return all_roles
  end

  def get_roles_with_specs
    roles_with_specs = []

    Dir.chdir(BASE_DIR) do
      get_all_roles.each do |role|
        successes = 0

        Dir.glob("roles/#{role}/spec/*_spec.rb").each do |file|
          successes =+ 1 if File.size(file) > 1
        end

        roles_with_specs << File.basename(role) if successes > 0
      end
    end

    return roles_with_specs
  end

  def get_roles_without_specs
    get_all_roles - get_roles_with_specs
  end

  def check_role_directory_available(role)
    Dir.chdir(BASE_DIR) do
      if ! Dir.exists?("roles/#{role}")
        log.error "Directory 'roles/#{role}' does not exist. That's strange, isn't it?"
        return false
      end
    end

    return true
  end

  def check_role_specs_available(role)
    Dir.chdir(BASE_DIR) do
      successes = 0

      Dir.glob("roles/#{role}/spec/*_spec.rb").each do |file|
        successes =+ 1 if File.size(file) > 1
      end

      if successes == 0
        # log.error "'#{role}' does not have specs but you requested me to run specs. Huu?"
        return false
      end
    end

    return true
  end

  def get_hosts_where_role_is_used(role)
    role_used_in_hosts = []

    Dir.chdir(BASE_DIR) do
      YAML.load_file("site.yml").each do |playbook|
        YAML.load_file(playbook['include'].to_s).each do |site|
          site['roles'].each do |playbook_role|
            if playbook_role.respond_to?(:each)
              role_used_in_hosts << site['name'].to_s if playbook_role['role'].include?(role)
            else
              role_used_in_hosts << site['name'].to_s if playbook_role.include?(role)
            end
          end
        end
      end
    end

    return role_used_in_hosts
  end

  def load_role_resources(name)
    resources = []

    Dir.chdir(BASE_DIR) do
      Dir.glob("roles/#{name}/tasks/*.yml").each do |file|
        AnsibleSpec.load_playbook(file).each do |resource|
          resources << resource
        end
      end
    end

    return resources
  end

  def create_role_rake_task(role)
    Dir.chdir(BASE_DIR) do
      properties = AnsibleSpecHelper.get_properties
      cfg = AnsibleSpec::AnsibleCfg.new
      get_hosts_where_role_is_used = get_hosts_where_role_is_used(role)

      properties.each do |property|
        next unless property['name'] == get_hosts_where_role_is_used.first

        if property['hosts'].empty?
          if ! get_hosts_from_vai_host_file.keys.include?(get_hosts_where_role_is_used.first)
            raise "Uuups. I cannot find '#{get_hosts_where_role_is_used.first}' in your hosts file. 'vagrant up #{get_hosts_where_role_is_used.first}' may help."
          end

          get_hosts_from_vai_host_file.each do |host, values|
            values.each do |property|
              next unless property['name'] == get_hosts_where_role_is_used.first

              RSpec::Core::RakeTask.new(role.to_sym) do |t|
                log.info "Run role tests for #{role} on #{get_hosts_where_role_is_used.first} (#{property["ansible_ssh_host"]}:#{property["ansible_ssh_port"]})"

                ENV['TARGET_HOST'] = property["ansible_ssh_host"]
                ENV['TARGET_PORT'] = property["ansible_ssh_port"].to_s
                ENV['TARGET_PRIVATE_KEY'] = property["ansible_ssh_private_key_file"]
                ENV['TARGET_USER'] = property["ansible_ssh_user"]

                t.pattern = '{' + cfg.roles_path.join(',') + '}/{' + role + '}/spec/*_spec.rb'
              end
            end
          end
        else
          property['hosts'].each do |host|
            RSpec::Core::RakeTask.new(role.to_sym) do |t|
              log.info "Run role tests for #{role} on #{get_hosts_where_role_is_used.first} (#{host['uri']})"

              ENV['TARGET_HOST'] = host['uri']

              t.pattern = '{' + cfg.roles_path.join(',') + '}/{' + role + '}/spec/*_spec.rb'
            end
          end
        end
      end
    end
  end

  ################
  # HOST METHODS #
  ################

  def list_host_specs
    get_hosts_with_specs.each do |host|
      command = "asp hostspec #{host}"
      description = "# run host specs for #{host}"

      puts "#{command} #{description.rjust(40)}"
    end
  end

  def create_host_rake_task(host)
    Dir.chdir(BASE_DIR) do
      properties = AnsibleSpecHelper.get_properties
      cfg = AnsibleSpec::AnsibleCfg.new

      properties.each do |property|
        next unless property['name'] == host

        if property['hosts'].empty?
          get_hosts_from_vai_host_file.each do |host, values|
            values.each do |property|
              RSpec::Core::RakeTask.new(host.to_sym) do |t|
                log.info "Run host tests for #{host}"

                ENV['TARGET_HOST'] = property["ansible_ssh_host"]
                ENV['TARGET_PORT'] = property["ansible_ssh_port"].to_s
                ENV['TARGET_PRIVATE_KEY'] = property["ansible_ssh_private_key_file"]
                ENV['TARGET_USER'] = property["ansible_ssh_user"]

                t.pattern = "spec/#{host}/*_spec.rb"
              end
            end
          end
        else
          property['hosts'].each do |host|
            RSpec::Core::RakeTask.new(property["name"].to_sym) do |t|
              log.info "Run host tests for #{property["name"]}"

              ENV['TARGET_HOST'] = host['uri']

              t.pattern = "spec/#{property["name"]}/*_spec.rb"
            end
          end
        end
      end
    end
  end

  def run_host_spec(host)
    create_host_rake_task(host)

    Dir.chdir(BASE_DIR) do
      Rake.application.invoke_task("#{host}")
    end

    calculate_coverage('host', host)
  end

  def load_host_resources(name)
    resources = []

    Dir.chdir(BASE_DIR) do
      YAML.load_file('./site.yml').each do |site|
        next unless site.values[0] =~ /#{name}\.(yml|yaml)/

        playbook_path = site.values[0]

        AnsibleSpec.load_playbook(playbook_path).each do |playbook|
          next if playbook['tasks'].nil?

          playbook['tasks'].map { |task| resources << task }
        end
      end
    end

    return resources.flatten
  end

  def get_hosts_with_specs
    hosts_with_specs = []

    get_vagrant_or_regular_ansible_hosts.each do |host|
      hosts_with_specs << host if check_for_host_specs(host)
    end

    return hosts_with_specs.uniq
  end

  def get_vagrant_or_regular_ansible_hosts
    hosts = []

    Dir.chdir(BASE_DIR) do
      properties = AnsibleSpecHelper.get_properties
      cfg = AnsibleSpec::AnsibleCfg.new

      properties.each do |property|
        if property['hosts'].empty?
          get_hosts_from_vai_host_file.each do |host, values|
            values.each do |property|
              hosts << property['name'] if check_for_existing_playbook(property['name'])
            end
          end
        else
          property['hosts'].each do |host|
            hosts << property['name'] if check_for_existing_playbook(property['name'])
          end
        end
      end
    end

    return hosts
  end

  def check_for_host_specs(host)
    Dir.chdir(BASE_DIR) do
      if File.directory?("./spec/#{host}")
        Dir.glob("./spec/#{host}/*_spec.rb").each do |file|
          if check_for_specs_in_file(file)
            return true
          else
            return false
          end
        end
      else
        return false
      end
    end
  end

  def get_roles_of_host(host)
    roles_with_specs = []

    Dir.chdir(BASE_DIR) do
      playbook_path = ''

      YAML.load_file('./site.yml').each do |site|
        next unless site.values[0] =~ /#{host}\.(yml|yaml)/

        playbook_path = site.values[0]
      end

      YAML.load_file(playbook_path).each do |playbook|
        playbook['roles'].each do |role|
          roles_with_specs << role if check_role_specs_available(role)
        end
      end
    end

    return roles_with_specs.uniq
  end

  ####################
  # PLAYBOOK METHODS #
  ####################

  def list_playbook_specs
    get_playbooks_with_host_and_or_role_specs.each do |playbook|
      command = "asp playbookspec #{playbook}"
      description = "# run playbook specs (host specs and role specs) for #{playbook} playbook"

      puts "#{command} #{description.rjust(77)}"
    end
  end

  def run_playbook_spec(playbook)
    create_playbook_rake_task(playbook)

    Dir.chdir(BASE_DIR) do
      Rake.application.invoke_task("#{playbook}")
    end

    calculate_coverage('playbook', playbook)
  end

  def create_playbook_rake_task(playbook)
    ENV['TARGET_HOST'] = ''
    ENV['TARGET_PORT'] = ''
    ENV['TARGET_PRIVATE_KEY'] = ''
    ENV['TARGET_USER'] = ''

    ansiblespec_roles = []

    hostname = playbook.gsub(/\.yml|\.yaml/,'')

    get_roles_of_host(hostname).each do |role|
      ansiblespec_roles << role if check_role_specs_available(role)
    end

    Dir.chdir(BASE_DIR) do
      properties = AnsibleSpecHelper.get_properties
      cfg = AnsibleSpec::AnsibleCfg.new

      if properties.select { |item| item['name'] == hostname}[0]['hosts'].empty?
        get_hosts_from_vai_host_file.select { |name,_| name == hostname }.each do |item|
          ENV['TARGET_HOST'] = item.flatten.last['ansible_ssh_host']
          ENV['TARGET_PORT'] = item.flatten.last['ansible_ssh_port']
          ENV['TARGET_PRIVATE_KEY'] = item.flatten.last['ansible_ssh_private_key_file']
          ENV['TARGET_USER'] = item.flatten.last['ansible_ssh_user']
        end
      else
        ENV['TARGET_HOST'] = properties.select { |item| item['name'] == hostname}[0]['hosts']['uri']
      end

      RSpec::Core::RakeTask.new("#{hostname}".to_sym) do |t|
        log.info "Run playbook tests for #{hostname}"

        roles_pattern = ",{#{cfg.roles_path.join(',')}}/{#{ansiblespec_roles.uniq.join(',')}}/spec/*_spec.rb" unless ansiblespec_roles.nil?
        host_pattern = ",spec/#{hostname}/*_spec.rb" if check_for_host_specs(hostname)

        t.pattern << roles_pattern + host_pattern
      end
    end
  end

  def load_playbook_resources(name)
    resources = []

    # collect role resources
    Dir.chdir(BASE_DIR) do
      YAML.load_file('./site.yml').each do |site|
        next unless site.values[0] =~ /#{name}\.(yml|yaml)/

        playbook_path = site.values[0]

        AnsibleSpec.load_playbook(playbook_path).each do |playbook|
          playbook['roles'].map { |role| resources << load_role_resources(role) }
        end
      end
    end

    # collect host resources
    resources = resources.flatten + load_host_resources(name)

    return resources
  end

  def check_for_existing_playbook(host)
    Dir.chdir(BASE_DIR) do
      if File.exists?("#{host}.yml")
        return true
      else
        return false
      end
    end
  end

  def get_playbooks_host_spec_summary
    playbooks = []

    Dir.chdir(BASE_DIR) do
      YAML.load_file('./site.yml').each do |site|
        Dir.glob(site.values[0]).each do |playbook|
          playbook = File.basename(playbook)
          host = playbook.gsub(/\.yml|\.yaml/,'')

          playbooks << { playbook => check_for_host_specs(host) }
        end
      end
    end

    return playbooks.uniq
  end

  def get_playbooks_with_host_and_or_role_specs
    playbooks = []

    get_playbooks_host_spec_summary.each do |entry|
      host = entry.keys[0].gsub(/\.yml|\.yaml/,'')
      has_specs = entry.values[0]

      if has_specs
        playbooks << host
      else
        get_roles_of_host(host).each do |role|
          playbooks << host if check_role_specs_available(role)
        end
      end
    end

    return playbooks.uniq
  end
end
