# frozen_string_literal: true

RSpec.describe Resque::Plugins::Prioritize::ResqueSchedulerUtilExtension do
  describe '.constantize' do
    subject(:klass) { Resque::Scheduler::Util.constantize(klass_name) }

    context 'without priority' do
      let(:klass_name) { 'TestWorker' }

      it { is_expected.to eq TestWorker }
      it { expect(klass.instance_variable_get(:@resque_prioritize_priority)).to eq nil }
    end

    context 'with priority' do
      let(:klass_name) { 'TestWorker{{priority}:20}' }

      it { is_expected.to eq TestWorker.with_priority(20) }
      it { expect(klass.instance_variable_get(:@resque_prioritize_priority)).to eq 20 }
    end

    context 'with invalid data' do
      let(:klass_name) { 'TestWorker{{priority}:20}test' }

      its_block { is_expected.to raise_error NameError }
    end

    context 'when instance of class' do
      let(:klass_name) { TestWorker }

      it { is_expected. to eq TestWorker }
    end
  end
end
