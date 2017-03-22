require_relative '../spec_helper'
require_relative '../lib/ansible_spec_plus'

describe RolesHelper do
  include Helpers::Log

  subject { described_class }

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

    it "returns log message that indicates an error" do
      # GIVEN
      allow(Dir).to receive(:glob).with('roles/foo/spec/*_spec.rb').and_return ['roles/foo/spec/foo_spec.rb']
      allow(File).to receive(:size).with('roles/foo/spec/foo_spec.rb').and_return 1

      # THEN
      expect(log).to receive(:error).with("'foo' does not have specs but you requested me to run specs. Huu?")

      # WHEN
      subject.check_role_specs_available('foo')
    end
  end

  describe "find_role_usage_in_hosts" do
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
      res = subject.find_role_usage_in_hosts('role6')

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
      res = subject.find_role_usage_in_hosts('role1')

      # THEN
      expect(res).to eq ['foo','boo']
    end
  end
end
