# frozen_string_literal: true

require 'securerandom'

# This acceptance specs wotks with TestWorker from `spec/fixures/test_workers.rb`
# Every worker on perform write to redis constant messsage that he works with this args.
# And when he finish performing - he write the same message, but about finish processing.
# In this specs we check output results of all workers. That all workers work exactly number of times
# And with correct arguments.
# To wait until all workers will finish work we use methods:
#   - wait_for_workers
#
# NOTE: Test it only with one queue, to be sure, that resque multiprocesing not broke expected output,
# because of we don't use any locks for workers.
RSpec.describe Resque::Plugins::Prioritize do
  subject { Resque.redis.lrange(TestWorker::REDIS_KEY, 0, -1) }

  context 'without prioritized' do
    before do
      3.times { |i| Resque.enqueue(TestWorker, i + 3) }
      3.times { |i| Resque.enqueue_to(:other_queue, TestWorker, i) }
      wait_for_workers
    end

    let(:output_result) { 6.times.map { |i| worker_output(TestWorker, i) } }

    it { is_expected.to eq output_result }
  end

  context 'with prioritized' do
    before do
      (0..5).to_a.shuffle.each { |i| Resque.enqueue(TestWorker.with_priority(i), i) }
      (6..10).to_a.shuffle.each { |i| Resque.enqueue_to(:other_queue, TestWorker.with_priority(i), i) }
      wait_for_workers
    end

    let(:output_result) { 11.times.map { |i| worker_output(TestWorker.with_priority(10 - i), 10 - i) } }

    it { is_expected.to eq output_result }
  end

  def worker_output(worker_class, *args)
    "Processing #{worker_class} with args: #{args.to_json}"
  end

  def wait_for_workers
    sleep 1 until Resque.redis.keys.grep(/(queue:|test_worker_performing:)/).empty?
  end
end
