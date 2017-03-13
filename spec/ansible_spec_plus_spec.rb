require_relative '../spec_helper'
require_relative '../lib/ansible_spec_plus'

describe AnsibleSpecPlus do
  include Helpers::Log

  describe 'all' do
    subject { described_class.new({:all => true}) }

    it 'prints a info log message' do
      expect(log).to receive(:info).with('Hello World!')

      subject
    end
  end
end
