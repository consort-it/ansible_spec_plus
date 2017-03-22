require_relative '../spec_helper'
require_relative '../lib/ansible_spec_plus'

describe AnsibleSpecPlus do
  include Helpers::Log

  describe 'list_role_specs' do
    subject { described_class.new({:role_spec_list => true}) }

    it 'prints commands for running specs for roles' do
      all_roles = ['test1', 'test2', 'test3']

      allow(RolesHelper).to receive(:get_roles_with_specs).and_return(all_roles)
      allow(RolesHelper).to receive(:get_roles_without_specs).and_return []

      expect do
        subject
      end.to output("asp rolespec test1               # run role specs for test1\nasp rolespec test2               # run role specs for test2\nasp rolespec test3               # run role specs for test3\n").to_stdout
    end

    it 'prints notice for roles without specs' do
      all_roles = ['test1', 'test2', 'test3']
      roles_without_specs = ['foo', 'bar']

      allow(RolesHelper).to receive(:get_roles_with_specs).and_return(all_roles)
      allow(RolesHelper).to receive(:get_roles_without_specs).and_return(roles_without_specs)

      expect do
        subject
      end.to output("asp rolespec test1               # run role specs for test1\nasp rolespec test2               # run role specs for test2\nasp rolespec test3               # run role specs for test3\n\nYou may want to add specs for this role(s), too:\n- foo\n- bar\n").to_stdout
    end
  end

  # describe 'run_role_spec' do
  #   subject { described_class.new({:role_spec_run => 'foo_role'}) }
  #
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
end
