# frozen_string_literal: true

RSpec.describe Resque::Plugins::Prioritize::Serializer do
  describe '#serialize' do
    subject { described_class.serialize(original, **vars) }

    let(:original) { TestWorker }
    let(:vars) { {test: 1, lal: 2, lol: :lalka} }

    it { is_expected.to eq 'TestWorker{{test}:1}{{lal}:2}{{lol}:lalka}' }

    context 'when vars present' do
      let(:vars) { {} }

      it { is_expected.to eq 'TestWorker' }
    end

    context 'when original is string' do
      let(:original) { 'TestWorker_string' }

      it { is_expected.to eq 'TestWorker_string{{test}:1}{{lal}:2}{{lol}:lalka}' }
    end

    context 'when original is nil' do
      let(:original) {}

      it { is_expected.to eq '{{test}:1}{{lal}:2}{{lol}:lalka}' }
    end
  end

  describe '#extract' do
    subject { ->(*var_keys) { described_class.extract(string, *var_keys) } }

    let(:string) { 'TestWorker{{priority}:10}{{uuid}:123}{{test}:test data}' }

    its_call { is_expected.to ret(rest: string) }
    its_call(:lal) { is_expected.to ret(rest: string, lal: nil) }
    its_call(:uuid) {
      is_expected.to ret(rest: 'TestWorker{{priority}:10}{{test}:test data}', uuid: '123')
    }
    its_call(:uuid, :test, :priority, :lal) {
      is_expected.to ret(
        rest: 'TestWorker', priority: '10', test: 'test data', uuid: '123', lal: nil
      )
    }
  end
end
