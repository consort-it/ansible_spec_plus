require_relative '../spec_helper'
require_relative '../lib/ansible_spec_plus'
require_relative '../lib/ansiblespec_helper'

describe AnsibleSpecPlus do
  include Helpers::Log

  subject { described_class.new }

  describe 'list_all_specs' do
    it "lists specs for roles, hosts and playbook at once" do
      roles = ['role1', 'role2']
      hosts = ['host1']
      playbooks = ['playbook1', 'playbook2']

      host_file = { "host1" => {} }

      allow(subject).to receive(:get_roles_with_specs).and_return(roles)
      allow(subject).to receive(:get_hosts_with_specs).and_return(hosts)
      allow(subject).to receive(:get_playbooks_with_host_and_or_role_specs).and_return(playbooks)
      allow(subject).to receive(:get_hosts_from_vai_host_file).and_return(host_file)

      # WHEN / THEN
      expect do
        subject.list_all_specs
      end.to output("asp rolespec role1               # run role specs for role1\nasp rolespec role2               # run role specs for role2\nasp hostspec host1               # run host specs for host1\nasp playbookspec playbook1       # run playbook specs (host specs and role specs) for playbook1 playbook\nasp playbookspec playbook2       # run playbook specs (host specs and role specs) for playbook2 playbook\n").to_stdout
    end
  end

  describe 'list_role_specs' do
    it 'prints commands for running specs for roles' do
      all_roles = ['test1', 'test2', 'test3']

      allow(subject).to receive(:get_roles_with_specs).and_return(all_roles)

      expect do
        subject.list_role_specs
      end.to output("asp rolespec test1               # run role specs for test1\nasp rolespec test2               # run role specs for test2\nasp rolespec test3               # run role specs for test3\n").to_stdout
    end
  end

  # describe 'run_role_spec' do
  #   it "does somthing" do
  #     # GIVEN
  #     allow(RolesHelper).to receive(:check_role_directory_available).with('foo_role').and_return true
  #     allow(RolesHelper).to receive(:check_role_specs_available).with('foo_role').and_return true
  #
  #     # WHEN
  #     res = subject
  #
  #     # THEN
  #     expect(res).to eq true
  #   end
  # end

  describe 'get_all_roles' do
    it 'returns an array of roles / directories' do
      # GIVEN
      file_list = ['/roles/test1', '/roles/test2', '/roles/test3']
      allow(Dir).to receive(:glob).and_return(file_list)

      # WHEN
      res = subject.get_all_roles

      # THEN
      expect(res).to eq ["test1", "test2", "test3"]
    end

    it "returns an empty array if no roles / directories are present" do
      # GIVEN
      allow(Dir).to receive(:glob).and_return []

      # WHEN
      res = subject.get_all_roles

      # THEN
      expect(res).to eq []
    end
  end

  describe 'get_roles_with_specs' do
    it 'returns an array with roles that have specs' do
      # GIVEN
      file_list = ['test1', 'test2', 'test3']
      allow(subject).to receive(:get_all_roles).and_return(file_list)

      allow(Dir).to receive(:glob).with('roles/test1/spec/*_spec.rb').and_return ['roles/test1/spec/foo_spec.rb']
      allow(Dir).to receive(:glob).with('roles/test2/spec/*_spec.rb').and_return []
      allow(Dir).to receive(:glob).with('roles/test3/spec/*_spec.rb').and_return ['roles/test3/spec/bar_spec.rb']

      allow(File).to receive(:size).with('roles/test1/spec/foo_spec.rb').and_return 123
      allow(File).to receive(:size).with('').and_return 0
      allow(File).to receive(:size).with('roles/test3/spec/bar_spec.rb').and_return 456

      # WHEN
      res = subject.get_roles_with_specs

      # THEN
      expect(res).to eq ['test1', 'test3']
    end

    it 'returns an array with roles that have specs with contents' do
      # GIVEN
      file_list = ['test1', 'test2']
      allow(subject).to receive(:get_all_roles).and_return(file_list)

      allow(Dir).to receive(:glob).with('roles/test1/spec/*_spec.rb').and_return ['roles/test1/spec/foo_spec.rb']
      allow(Dir).to receive(:glob).with('roles/test2/spec/*_spec.rb').and_return ['roles/test2/spec/doo_spec.rb']

      allow(File).to receive(:size).with('roles/test1/spec/foo_spec.rb').and_return 0
      allow(File).to receive(:size).with('roles/test2/spec/doo_spec.rb').and_return 123

      # WHEN
      res = subject.get_roles_with_specs

      # THEN
      expect(res).to eq ['test2']
    end
  end

  describe 'check_for_specs_in_file' do
    it "returns true if file contains 'describe '" do
      # GIVEN
      test_spec_file = ["require 'spec_helper'\n", "\n", "describe command('docker network ls') do\n"]
      allow(File).to receive(:readlines).with('test_spec.rb').and_return(test_spec_file)

      # WHEN
      res = subject.check_for_specs_in_file('test_spec.rb')

      # THEN
      expect(res).to eq true
    end

    it "does not return true if file contains no 'describe '" do
      # GIVEN
      test_spec_file = ["require 'spec_helper'\n", "\n"]
      allow(File).to receive(:readlines).with('test_spec.rb').and_return(test_spec_file)

      # WHEN
      res = subject.check_for_specs_in_file('test_spec.rb')

      # THEN
      expect(res).not_to eq true
      expect(res).to eq false
    end
  end

  describe 'get_hosts_with_specs' do
    it 'returns an array with hosts that have specs' do
      # GIVEN
      allow(subject).to receive(:get_vagrant_or_regular_ansible_hosts).and_return ['foo_host1', 'foo_host2', 'foo_host2']

      allow(subject).to receive(:check_for_host_specs).with('foo_host1').and_return false
      allow(subject).to receive(:check_for_host_specs).with('foo_host2').and_return true
      allow(subject).to receive(:check_for_host_specs).with('foo_host3').and_return false

      # WHEN
      res = subject.get_hosts_with_specs

      # THEN
      expect(res).to eq ['foo_host2']
    end
  end

  describe 'get_roles_without_specs' do
    it 'returns an array with name of roles that don\'t have specs' do
      # GIVEN
      allow(subject).to receive(:get_all_roles).and_return ['test1', 'test2', 'test3']
      allow(subject).to receive(:get_roles_with_specs).and_return ['test1', 'test3']

      # WHEN
      res = subject.get_roles_without_specs

      # THEN
      expect(res).to eq ['test2']
    end
  end

  describe 'check_role_directory_available' do
    it 'returns true if role directoy exists' do
      # GIVEN
      allow(Dir).to receive(:exists?).with('roles/foo').and_return true

      # WHEN
      res = subject.check_role_directory_available('foo')

      # THEN
      expect(res).to eq true
    end

    it "return false if directory does not exist" do
      # GIVEN
      allow(Dir).to receive(:exists?).with('roles/foo').and_return false
      allow(log).to receive(:error)

      # WHEN
      res = subject.check_role_directory_available('foo')

      # THEN
      expect(res).to eq false
    end

    it "logs an error if directory does not exist" do
      # GIVEN
      allow(Dir).to receive(:exists?).with('roles/foo').and_return false

      # THEN
      expect(log).to receive(:error).with("Directory 'roles/foo' does not exist. That's strange, isn't it?")

      # WHEN
      subject.check_role_directory_available('foo')
    end
  end

  describe 'check_role_specs_available' do
    it "returns true if spec file is not empty" do
      # GIVEN
      allow(Dir).to receive(:glob).with('roles/foo/spec/*_spec.rb').and_return ['roles/foo/spec/foo_spec.rb']
      allow(File).to receive(:size).with('roles/foo/spec/foo_spec.rb').and_return 123

      # WHEN
      res = subject.check_role_specs_available('foo')

      # THEN
      expect(res).to eq true
    end

    it "returns false if spec file is empty" do
      # GIVEN
      allow(Dir).to receive(:glob).with('roles/foo/spec/*_spec.rb').and_return ['roles/foo/spec/foo_spec.rb']
      allow(File).to receive(:size).with('roles/foo/spec/foo_spec.rb').and_return 0
      allow(log).to receive(:error)

      # WHEN
      res = subject.check_role_specs_available('foo')

      # THEN
      expect(res).to eq false
    end

    it "returns false if spec file has a newline" do
      # GIVEN
      allow(Dir).to receive(:glob).with('roles/foo/spec/*_spec.rb').and_return ['roles/foo/spec/foo_spec.rb']
      allow(File).to receive(:size).with('roles/foo/spec/foo_spec.rb').and_return 1
      allow(log).to receive(:error)

      # WHEN
      res = subject.check_role_specs_available('foo')

      # THEN
      expect(res).to eq false
    end

    it "returns false if there is an error" do
      # GIVEN
      allow(Dir).to receive(:glob).with('roles/foo/spec/*_spec.rb').and_return ['roles/foo/spec/foo_spec.rb']
      allow(File).to receive(:size).with('roles/foo/spec/foo_spec.rb').and_return 1

      # WHEN
      res = subject.check_role_specs_available('foo')

      # THEN
      expect(res).to eq false

    end
  end

  describe "get_hosts_where_role_is_used" do
    it "returns array with one host if role is only used there" do
      # GIVEN
      playbooks = [
        {"include"=>"foo.yml"},
        {"include"=>"boo.yml"}
      ]
      allow(YAML).to receive(:load_file).and_return(playbooks)

      foo_playbook = [{
        "name"=>"foo",
        "hosts"=>"foo-hosts",
        "roles"=>
         ["role1",
          "role2",
          "role3",
          "role4",
          "role5"]
      }]
      allow(YAML).to receive(:load_file).and_return(foo_playbook)

      boo_playbook = [{
        "name"=>"boo",
        "hosts"=>"boo-hosts",
        "roles"=>
         ["role1",
          "role6"]
      }]
      allow(YAML).to receive(:load_file).and_return(boo_playbook)

      # WHEN
      res = subject.get_hosts_where_role_is_used('role6')

      # THEN
      expect(res).to eq ['boo']
    end

    it "returns array with all hosts where role is used" do
      # GIVEN
      playbooks = [
        {"include"=>"foo.yml"},
        {"include"=>"boo.yml"}
      ]
      allow(YAML).to receive(:load_file).with('site.yml').and_return(playbooks)

      foo_playbook = [{
        "name"=>"foo",
        "hosts"=>"foo-hosts",
        "roles"=>
         ["role1",
          "role2",
          "role3",
          "role4",
          "role5"]
      }]
      allow(YAML).to receive(:load_file).with('foo.yml').and_return(foo_playbook)

      boo_playbook = [{
        "name"=>"boo",
        "hosts"=>"boo-hosts",
        "roles"=>
         ["role1",
          "role6"]
      }]
      allow(YAML).to receive(:load_file).with('boo.yml').and_return(boo_playbook)

      # WHEN
      res = subject.get_hosts_where_role_is_used('role1')

      # THEN
      expect(res).to eq ['foo','boo']
    end

    it "returns array with one host if role of typ hash is used" do
      # GIVEN
      playbooks = [
        {"include"=>"foo.yml"},
        {"include"=>"boo.yml"}
      ]
      allow(YAML).to receive(:load_file).with('site.yml').and_return(playbooks)

      foo_playbook = [{
        "name"=>"foo",
        "hosts"=>"foo-hosts",
        "roles"=>
         ["role1",
          "role2",
          "role3",
          {"role"=>"role4"},
          "role5"]
      }]
      allow(YAML).to receive(:load_file).with('foo.yml').and_return(foo_playbook)

      boo_playbook = [{
        "name"=>"boo",
        "hosts"=>"boo-hosts",
        "roles"=>
         ["role1",
          "role6"]
      }]
      allow(YAML).to receive(:load_file).with('boo.yml').and_return(boo_playbook)

      # WHEN
      res = subject.get_hosts_where_role_is_used('role4')

      # THEN
      expect(res).to eq ['foo']
    end
  end

  describe 'load_role_resources' do
    it 'returns resources for a given role' do
      # GIVEN
      allow(Dir).to receive(:glob).with('roles/test_role/tasks/*.yml').and_return ['roles/test_role/tasks/test_role.yml']

      resources = [
        {
          "name"=>"create deploy user",
          "user"=> {"name"=>"deploy", "comment"=>"User for deployments", "append"=>true},
          "roles"=>[]
        },
        {
          "name"=>"sudo right for deploy user is present",
          "template"=> "src=sudo/deploy dest=/etc/sudoers.d/deploy owner=root group=root mode=0440",
          "roles"=>[]
        }
      ]
      allow(AnsibleSpec).to receive(:load_playbook).with('roles/test_role/tasks/test_role.yml').and_return(resources)

      # WHEN
      res = subject.load_role_resources('test_role')

      # THEN
      expect(res).to eq [{"name"=>"create deploy user", "user"=> {"name"=>"deploy", "comment"=>"User for deployments", "append"=>true}, "roles"=>[]},{"name"=>"sudo right for deploy user is present", "template"=> "src=sudo/deploy dest=/etc/sudoers.d/deploy owner=root group=root mode=0440", "roles"=>[]}]
    end
  end

  describe 'load_host_resources' do
    it 'returns resources for a given host' do
      # GIVEN
      playbook = [{
        "hosts"=>"foo-hosts",
        "name"=>"foo",
        "remote_user"=>"vagrant",
        "serial"=>1,
        "vars_files"=>["roles/cme-infrastructure/vars/secrets.yml"],
        "roles"=>
         ["common",
          "docker",
          "docker-compose",
          "docker-flow",
          "java",
          "maven",
          "cme-infrastructure",
          "cme-demo"],
        "tasks"=>
         [{"name"=>"Debian python-pymongo is present",
           "pip"=>{"name"=>"pymongo", "state"=>"latest"}},
          {"name"=>"create mongodb user and database 'hello-world-java'",
           "mongodb_user"=>
            {"login_user"=>"root",
             "login_password"=>"secret",
             "login_database"=>"admin",
             "database"=>"hello-world-java",
             "name"=>"hello-world-java",
             "password"=>"hello-world-java",
             "roles"=>"readWrite,dbAdmin",
             "state"=>"present"}}]
      }]

      allow(YAML).to receive(:load_file).with('./site.yml').and_return [{"include"=>"foo.yml"}]
      allow(AnsibleSpec).to receive(:load_playbook).with('foo.yml').and_return(playbook)

      # WHEN
      res = subject.load_host_resources('foo')

      # THEN
      expect(res).to eq [{"name"=>"Debian python-pymongo is present", "pip"=>{"name"=>"pymongo", "state"=>"latest"}}, {"name"=>"create mongodb user and database 'hello-world-java'", "mongodb_user"=> {"login_user"=>"root", "login_password"=>"secret", "login_database"=>"admin", "database"=>"hello-world-java", "name"=>"hello-world-java", "password"=>"hello-world-java", "roles"=>"readWrite,dbAdmin", "state"=>"present"}}]
    end

    it 'returns no resources for a given host if there are none' do
      # GIVEN
      playbook = [{
        "hosts"=>"foo-hosts",
        "name"=>"foo",
        "remote_user"=>"vagrant",
        "serial"=>1,
        "vars_files"=>["roles/cme-infrastructure/vars/secrets.yml"],
        "roles"=>
         ["common",
          "docker",
          "docker-compose",
          "docker-flow",
          "java",
          "maven",
          "cme-infrastructure",
          "cme-demo"]
      }]

      allow(YAML).to receive(:load_file).with('./site.yml').and_return [{"include"=>"foo.yml"}]
      allow(AnsibleSpec).to receive(:load_playbook).with('foo.yml').and_return(playbook)

      # WHEN
      res = subject.load_host_resources('foo')

      # THEN
      expect(res).to eq []
    end
  end

  describe 'analyze_resources' do
    it 'prints a log message for unknown resource "apt"' do
      # GIVEN
      stub_const('AnsibleSpecPlus::KNOWN_RESOURCES', ['file','template','docker_container','docker_image','service'])
      file_resource = [{"name"=>"ensure apt cache is up to date","apt"=>"update_cache=yes cache_valid_time=3600"}]

      # THEN
      expect(log).to receive(:warn).with('Unknown resource: {"name"=>"ensure apt cache is up to date", "apt"=>"update_cache=yes cache_valid_time=3600"}')

      # WHEN
      subject.analyze_resources(file_resource)
    end

    it 'returns a result for a string file resource' do
      # GIVEN
      stub_const('AnsibleSpecPlus::KNOWN_RESOURCES', ['file','template','docker_container','docker_image','service'])
      file_resource = [{"name"=>"test one","file"=>"path=/git/.ssh state=directory owner=git group=git mode=0755"}]

      # WHEN
      res = subject.analyze_resources(file_resource)

      # THEN
      expect(res).to eq ["File \"/git/.ssh\""]
    end

    it 'returns a empty result for a string file resource if path contains double {{ }}' do
      # GIVEN
      stub_const('AnsibleSpecPlus::KNOWN_RESOURCES', ['file','template','docker_container','docker_image','service'])
      file_resource = [{"name"=>"test one","file"=>"path=/opt/{{item.0}}/{{item.1}} state=directory owner=git group=git mode=0755"}]
      allow(log).to receive(:warn)

      # WHEN
      res = subject.analyze_resources(file_resource)

      # THEN
      expect(res).to eq []
    end

    it 'returns a result for a hash file resource' do
      # GIVEN
      stub_const('AnsibleSpecPlus::KNOWN_RESOURCES', ['file','template','docker_container','docker_image','service'])
      file_resource = [{"name"=>"Ensure webroot exists", "file"=>{"path"=>"/some/path","state"=>"directory","follow"=>true},"become"=>true,"roles"=>[]}]

      # WHEN
      res = subject.analyze_resources(file_resource)

      # THEN
      expect(res).to eq ["File \"/some/path\""]
    end

    it 'returns a empty result for a hash file resource if path contains double {{ }}' do
      # GIVEN
      stub_const('AnsibleSpecPlus::KNOWN_RESOURCES', ['file','template','docker_container','docker_image','service'])
      file_resource = [{"name"=>"Ensure webroot exists", "file"=>{"path"=>"{{ letsencrypt_webroot_path }}","state"=>"directory","follow"=>true},"become"=>true,"roles"=>[]}]
      allow(log).to receive(:warn)

      # WHEN
      res = subject.analyze_resources(file_resource)

      # THEN
      expect(res).to eq []
    end

    it 'returns a result for a string template resource' do
      # GIVEN
      stub_const('AnsibleSpecPlus::KNOWN_RESOURCES', ['file','template','docker_container','docker_image','service'])
      file_resource = [{"name"=>"fix 'stdin is not a tty' warning","template"=>"src=profile dest=/root/.profile owner=root group=root mode=0644","roles"=>[]}]

      # WHEN
      res = subject.analyze_resources(file_resource)

      # THEN
      expect(res).to eq ["File \"/root/.profile\""]
    end
  end
end
