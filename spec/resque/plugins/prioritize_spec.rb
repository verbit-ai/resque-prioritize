# frozen_string_literal: true

RSpec.describe Resque::Plugins::Prioritize do
  describe '.prioritized_queue_postfix' do
    subject { described_class.prioritized_queue_postfix }

    it { is_expected.to eq '_prioritized' }

    context 'when change default' do
      around do |example|
        described_class.instance_variable_set(:@prioritized_queue_postfix, '_super_prioritized')
        example.run
        described_class.instance_variable_set(:@prioritized_queue_postfix, '_prioritized')
      end

      it { is_expected.to eq '_super_prioritized' }
    end
  end

  describe '.with_priority' do
    subject { TestWorker.with_priority(priority) }

    let(:priority) { 20 }

    %i[to_s name inspect].each do |m|
      its(m) { is_expected.to eq 'TestWorker{{priority}:20}' }
    end

    describe 'instance_variables' do
      subject { super().method(:instance_variable_get) }

      its_call(:@resque_prioritize_priority) { is_expected.to ret 20 }
      its_call(:@queue) { is_expected.to ret :test_prioritized }
    end

    describe 'equality' do
      subject { super().method(:==) }

      its_call(TestWorker) { is_expected.to ret false }
      its_call(TestWorker.with_priority(10)) { is_expected.to ret false }
      its_call(TestWorker.with_priority(20)) { is_expected.to ret true }
    end

    context 'when called twice' do
      subject { super().with_priority(40) }

      %i[to_s name inspect].each do |m|
        its(m) { is_expected.to eq 'TestWorker{{priority}:40}' }
      end
    end
  end

  describe '.without_priority' do
    subject { worker_class.without_priority }

    let(:worker_class) { TestWorker }

    it { is_expected.to eq TestWorker }

    context 'when worker_class with priority' do
      let(:worker_class) { TestWorker.with_priority(10) }

      it { is_expected.to eq TestWorker }
    end
  end
end
