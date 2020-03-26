# frozen_string_literal: true

# Spec without stubs, but also without process workers by resque.
# Redis works pretty fast to be sure that specs will be fast
# See `spec/fixtures/test_workers.rb` to see definition of TestWorker
RSpec.describe Resque::Plugins::Prioritize::DataStoreExtension, :not_watch_queues do
  describe '.push_to_queue' do
    subject { Resque.redis.push_to_queue(queue, Resque.encode(class: klass, args: args)) }

    let(:queue) { :test }
    let(:args) { [1, 2] }
    let(:klass) { 'TestWorker' }

    its_block {
      is_expected.to change { Resque.redis.lrange('queue:test', 0, -1) }
        .to match_array [Resque.encode(class: 'TestWorker', args: [1, 2])]
    }

    context 'with priority' do
      let(:klass) { 'TestWorker{{priority}:20}' }

      its_block {
        is_expected.to change { Resque.redis.zrevrange('queue:test_prioritized', 0, -1) }
          .to match_array [
            match('"class":"TestWorker{{priority}:20}","args":\[1,2\]')
              .and(match(Resque::Plugins::Prioritize::UUID_REGEXP))
          ]
      }
    end

    context 'with prioritized queue' do
      let(:queue) { :test_prioritized }
      let(:klass) { 'TestWorker{{priority}:20}' }

      its_block {
        is_expected.to change { Resque.redis.zrevrange('queue:test_prioritized', 0, -1) }
          .to match_array [
            match('"class":"TestWorker{{priority}:20}","args":\[1,2\]')
              .and(match(Resque::Plugins::Prioritize::UUID_REGEXP))
          ]
      }
    end
  end

  describe '.pop_from_queue' do
    subject { Resque.redis.method(:pop_from_queue) }

    before {
      3.times { |i| Resque.enqueue(TestWorker, i, i + 1) }
      4.times { |i| Resque.enqueue(TestWorker.with_priority(i), i + 10, i + 11) }
    }

    its_call(:test) { is_expected.to ret Resque.encode(class: 'TestWorker', args: [0, 1]) }
    its_call(:test_prioritized) { is_expected.to ret Resque.encode(class: TestWorker.with_priority(3), args: [13, 14]) }
  end

  describe '.queue_size' do
    subject { Resque.redis.method(:queue_size) }

    before {
      3.times { Resque.enqueue(TestWorker, 1) }
      5.times { Resque.enqueue(TestWorker.with_priority(5), 2) }
    }

    its_call(:test) { is_expected.to ret 3 }
    its_call(:test_prioritized) { is_expected.to ret 5 }
  end

  describe '.everything_in_queue' do
    subject { Resque.redis.method(:everything_in_queue) }

    before {
      3.times { |i| Resque.enqueue(TestWorker, i) }
      5.times { |i| Resque.enqueue(TestWorker.with_priority(i), i) }
    }

    its_call(:test) {
      is_expected.to ret(
        (0..2).map { |i| Resque.encode(class: TestWorker, args: [i]) }
      )
    }
    its_call(:test_prioritized) {
      is_expected.to ret(
        (0..4).map { |i| Resque.encode(class: TestWorker.with_priority(4 - i), args: [4 - i]) }
      )
    }
  end

  describe '.remove_from_queue' do
    subject { Resque.redis.method(:remove_from_queue) }

    before {
      Resque.enqueue(TestWorker, 1, 2)
      Resque.enqueue(TestWorker.with_priority(10), 3, 4)
    }

    its_call(:test, Resque.encode(class: 'TestWorker', args: [1, 2])) {
      is_expected.to change { Resque.redis.everything_in_queue(:test) }
        .from([Resque.encode(class: 'TestWorker', args: [1, 2])])
        .to([])
    }
    its_call(:test_prioritized, Resque.encode(class: 'TestWorker', args: [3, 4])) {
      is_expected.to change { Resque.redis.everything_in_queue(:test_prioritized) }
        .from([Resque.encode(class: 'TestWorker{{priority}:10}', args: [3, 4])])
        .to([])
    }
    its_call(:test_prioritized, Resque.encode(class: 'TestWorker{{priority}:10}', args: [3, 4])) {
      is_expected.to change { Resque.redis.everything_in_queue(:test_prioritized) }
        .from([Resque.encode(class: 'TestWorker{{priority}:10}', args: [3, 4])])
        .to([])
    }
  end

  describe '.list_range' do
    subject { Resque.redis.method(:list_range) }

    before {
      3.times { |i| Resque.enqueue(TestWorker, i) }
      5.times { |i| Resque.enqueue(TestWorker.with_priority(i), i) }
    }

    its_call('queue:test') { is_expected.to ret Resque.encode(class: TestWorker, args: [0]) }
    its_call('queue:test', 0, 2) {
      is_expected.to ret(
        (0..1).map { |i| Resque.encode(class: TestWorker, args: [i]) }
      )
    }
    its_call('queue:test', 1, 6) {
      is_expected.to ret(
        (1..2).map { |i| Resque.encode(class: TestWorker, args: [i]) }
      )
    }
    its_call('queue:test_prioritized') {
      is_expected.to ret Resque.encode(class: TestWorker.with_priority(4), args: [4])
    }
    its_call('queue:test_prioritized', 0, 2) {
      is_expected.to ret(
        (0..1).map { |i| Resque.encode(class: TestWorker.with_priority(4 - i), args: [4 - i]) }
      )
    }
    its_call('queue:test_prioritized', 1, 8) {
      is_expected.to ret(
        (1..4).map { |i| Resque.encode(class: TestWorker.with_priority(4 - i), args: [4 - i]) }
      )
    }
  end
end
