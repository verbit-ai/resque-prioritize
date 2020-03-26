# frozen_string_literal: true

# simple test worker
class TestWorker
  include Resque::Plugins::Prioritize

  REDIS_KEY = 'specs_output'

  @queue = :test

  def self.perform(*args)
    Resque.redis.set("test_worker_performing:#{key}", 'test')
    print_to_redis "Processing #{self} with args: #{args.to_json}"
  ensure
    Resque.redis.del("test_worker_performing:#{key}")
  end

  def self.print_to_redis(text)
    Resque.redis.rpush(REDIS_KEY, text)
    puts text
  end

  def self.key
    @key ||= SecureRandom.uuid
  end
end
