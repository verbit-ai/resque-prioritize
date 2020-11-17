# frozen_string_literal: true

RSpec.describe Resque::Plugins::Prioritize::PriorityWrapper do
  let(:instance) { described_class.new(original, priority) }

  let(:original) { TestWorker }
  let(:priority) { 10 }

  describe '#call' do
    subject { instance.call }

    describe 'validation' do
      its_block { is_expected.not_to raise_error }

      context 'when priority missed' do
        let(:priority) {}

        its_block { is_expected.to raise_error(described_class::ValidationError) }
      end

      context 'when priority missed' do
        let(:original) {}

        its_block { is_expected.to raise_error(described_class::ValidationError) }
      end
    end

    describe 'instance variables' do
      subject { super().method(:instance_variable_get) }

      its_call(:@resque_prioritize_priority) { is_expected.to ret 10 }
      its_call(:@queue) { is_expected.to ret :test_prioritized }
    end

    describe 'serializing' do
      %i[to_s name inspect].each do |m|
        its(m) { is_expected.to eq "TestWorker{{priority}:#{priority}}" }
      end
    end

    describe 'equality' do
      subject { super().method(:==) }

      its_call(TestWorker) { is_expected.to ret false }
      its_call(TestWorker.with_priority(10)) { is_expected.to ret true }
      its_call(TestWorker.with_priority(20)) { is_expected.to ret false }
    end
  end
end
