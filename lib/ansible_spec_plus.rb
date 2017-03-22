require_relative '../lib/helpers/log'

require 'rake'
require 'rspec/core/rake_task'
require 'yaml'
require 'ansible_spec'
require 'pp'
require 'json'

module AnsibleSpecPlus

  # TODO do not make this absolute
  BASE_DIR = '../vagrant-lifecycle'
  # BASE_DIR = '../ansible-infrastructure'

  include Helpers::Log

  def self.list_all_specs
    list_role_specs
    list_host_specs
    # list_playbook_specs
  end

  def self.list_role_specs
    get_roles_with_specs.each do |role|
      command = "asp rolespec #{role}"
      description = "# run role specs for #{role}"

      puts "#{command} #{description.rjust(40)}"
    end

    if get_roles_without_specs.size >= 1
      puts "\nYou may want to add specs for this role(s), too:"
      get_roles_without_specs.map { |r| puts "- #{r}" }
    end
  end

  def self.list_host_specs
    get_hosts_with_specs.each do |host|
      command = "asp hostspec #{host}"
      description = "# run host specs for #{host}"
      offline_notice = get_hosts_from_vai_host_file.keys.include?(host) ? "" : "(#{host} is offline. Tests won't run!)"

      puts "#{command} #{description.rjust(40)} #{offline_notice}"
    end
  end

  def self.run_role_spec(role)
    if check_role_directory_available(role) && check_role_specs_available(role)
      create_role_rake_task(role)

      Dir.chdir(BASE_DIR) do
        Rake.application["#{role}"].invoke()
      end

      calculate_coverage('role', role)
    end
  end

  def self.run_host_spec(host)
    create_host_rake_task(host)

    # Dir.chdir(BASE_DIR) do
    #   Rake.application["#{host}"].invoke()
    # end

    calculate_coverage('host', host)
  end

  def self.get_all_roles
    all_roles = []

    Dir.chdir(BASE_DIR) do
      Dir.glob("roles/*").each do |role|
        all_roles << File.basename(role)
      end
    end

    return all_roles
  end

  def self.get_roles_with_specs
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

  def self.get_hosts_with_specs
    hosts_with_specs = []

    Dir.chdir(BASE_DIR) do
      Dir.glob('./spec/*').each do |dir|
        next unless File.directory?(dir)

        Dir.glob("#{dir}/*_spec.rb").each do |file|
          hosts_with_specs << File.basename(dir) if File.size(file) > 1
        end
      end
    end

    return hosts_with_specs.uniq
  end

  def self.get_roles_without_specs
    get_all_roles - get_roles_with_specs
  end

  def self.check_role_directory_available(role)
    Dir.chdir(BASE_DIR) do
      if ! Dir.exists?("roles/#{role}")
        log.error "Directory 'roles/#{role}' does not exist. That's strange, isn't it?"
        return false
      end
    end

    return true
  end

  def self.check_role_specs_available(role)
    Dir.chdir(BASE_DIR) do
      successes = 0

      Dir.glob("roles/#{role}/spec/*_spec.rb").each do |file|
        successes =+ 1 if File.size(file) > 1
      end

      if successes == 0
        log.error "'#{role}' does not have specs but you requested me to run specs. Huu?"
        return false
      end
    end

    return true
  end

  def self.get_hosts_where_role_is_used(role)
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

  def self.load_role_resources(name)
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

  def self.load_host_resources(name)
    resources = []

    Dir.chdir(BASE_DIR) do
      AnsibleSpec.load_playbook("#{name}.yml").each do |playbook|
        playbook['roles'].each do |role|
          resources << load_role_resources(role)
        end
      end
    end

    return resources.flatten
  end

  def self.analyze_resources(resources)
    analyzed_resources = []

    resources.each do |resource|
      resource_type = nil

      resource.keys.each do |key|
        resource_type = key if KNOWN_RESOURCES.include?(key)
      end

      if resource_type.nil?
        log.warn "Unknown resource (excluding from summary): #{resource}"
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
      end

      analyzed_resources << "#{resource_type} \"#{resource_name}\""
    end

    return analyzed_resources
  end

  def self.get_hosts_from_vai_host_file
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

  def self.create_role_rake_task(role)
    Dir.chdir(BASE_DIR) do
      properties = AnsibleSpec.get_properties
      cfg = AnsibleSpec::AnsibleCfg.new

      properties.each do |property|
        next unless property['name'] == get_hosts_where_role_is_used(role).first

        if property['hosts'].empty?
          if ! get_hosts_from_vai_host_file.keys.include?(get_hosts_where_role_is_used(role).first)
            log.error "Host doesn't seem to exist. You may want to boot it?"
          end

          get_hosts_from_vai_host_file.each do |host, values|
            values.each do |property|
              next unless property['name'] == get_hosts_where_role_is_used(role).first

              RSpec::Core::RakeTask.new(role.to_sym) do |t|
                log.info "Run role tests for #{role} on #{get_hosts_where_role_is_used(role).first} (#{property["ansible_ssh_host"]}:#{property["ansible_ssh_port"]})"

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
              log.info "Run role tests for #{role} on #{get_hosts_where_role_is_used(role).first} (#{host['uri']})"

              ENV['TARGET_HOST'] = host['uri']

              t.pattern = '{' + cfg.roles_path.join(',') + '}/{' + role + '}/spec/*_spec.rb'
            end
          end
        end
      end
    end
  end

  def self.create_host_rake_task(host)
    Dir.chdir(BASE_DIR) do
      properties = AnsibleSpec.get_properties
      cfg = AnsibleSpec::AnsibleCfg.new

      properties.each do |property|
        if property['hosts'].empty?
          if ! get_hosts_from_vai_host_file.keys.include?(host)
            log.error "Host '#{host}' doesn't seem to be up or even exist."
            exit 0
          end

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

  def self.print_rounded_role_coverage(all_resources, differences)
    if all_resources.count == 0
      return "0%"
    else
      "#{((all_resources - differences).count.to_f / all_resources.count.to_f * 100.0).round}%"
    end
  end

  def self.calculate_coverage(type, name)
    Dir.chdir(BASE_DIR) do
      json_report = File.read('report.json')
      parsed_report = JSON.parse(json_report)

      case type
      when 'role'
        all_resources = analyze_resources(load_role_resources(name))
      when 'host'
        all_resources = analyze_resources(load_host_resources(name))
      else
        log.error "Unknow type '#{type}'. Should be either role, host or playbook."
        exit 1
      end

      tested_resources = []

      parsed_report['examples'].each do |example|
        tested_resources << example['full_description'].gsub(/"\s{1}.*/,'"')
      end

      tested_resources = tested_resources.uniq

      differences = []

      all_resources.each do |resource|
        differences << resource if ! tested_resources.include?(resource)
      end

      puts "Total resources: #{all_resources.count}"
      puts "Touched resources: #{(all_resources - differences).count}"
      puts "Resource coverage: #{print_rounded_role_coverage(all_resources, differences)}"

      if differences.count > 0
        puts "\nUncovered resources:"
        differences.each do |item|
          puts "- #{item}"
        end
      end
    end
  end

  def self.read_all_yaml_files
    yaml = {}

    Dir.chdir(BASE_DIR) do
      Dir.glob("**/*.yml").each do |file|
        next if YAML.load_file(file).nil?

        yaml[file] = YAML.load_file(file)
      end
    end

    return yaml
  end

end
