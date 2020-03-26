# frozen_string_literal: true

require 'bundler/setup'
require 'rspec'
require 'saharspec'
require 'rspec/its'
require 'pry'
require 'resque/plugins/prioritize'

Resque.redis = 'localhost:6379/resque_prioritize_test'

require_relative 'fixtures/test_workers'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # remove all test redis keys
  config.after do
    Resque.redis.del(
      TestWorker::REDIS_KEY,
      'queues',
      *Resque.redis.keys('queue:*')
    )
  end

  config.before(:example, :not_watch_queues) do
    allow(Resque.redis.instance_variable_get(:@redis)).to receive(:sadd)
      .with(:queues, any_args).and_return(true)
  end
end
