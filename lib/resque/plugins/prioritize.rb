# frozen_string_literal: true

require 'resque'
require_relative 'prioritize/version'

require_relative 'prioritize/serializer'
require_relative 'prioritize/priority_wrapper'

require_relative 'prioritize/resque_extension'
require_relative 'prioritize/data_store_extension'
require_relative 'prioritize/redis_future_extension'

Resque.prepend Resque::Plugins::Prioritize::ResqueExtension
Resque::DataStore.prepend Resque::Plugins::Prioritize::DataStoreExtension
Redis::Future.include Resque::Plugins::Prioritize::RedisFutureExtension

begin
  require 'resque-scheduler'
  require_relative 'prioritize/resque_scheduler_util_extension'

  Resque::Scheduler::Util.prepend Resque::Plugins::Prioritize::ResqueSchedulerUtilExtension
rescue LoadError # rubocop:disable Lint/SuppressedException
end

module Resque
  module Plugins
    # Plugin to prioritize Resque job's inside a queue.
    # Usage:
    #   Resque.enqueue(TestWorker.with_priority(10), 1)
    #
    # It is implemented by returning inherited class with redefined stringify methods.
    # Also overriding Resque::DataStore::QueueAccess class to work with zset, instead of list,
    # when you trying to put into queue class with priority.
    # For normal classes, without priority, works without changes.
    #
    # To separate two types of lists, queue with zset have the same name as normal queue,
    # but with some postfix. By default postfix is '_prioritized', but you could to override it:
    #   `Prioritize.prioritized_queue_postfix = '_my_new_prioritized_postfix'`
    #
    # So, if TestWorker has a @queue :test, and you will enqueue it with priority, Resque will put
    # it into `test_prioritized` queue.
    module Prioritize
      @prioritized_queue_postfix = '_prioritized'

      class << self
        attr_accessor :prioritized_queue_postfix

        def included(base)
          base.extend ClassMethods
        end

        def to_prioritized_queue(queue)
          queue = queue.to_s

          :"#{queue}#{prioritized_queue_postfix unless queue.include?(prioritized_queue_postfix)}"
        end

        # Needs to be used with the Resque "constantize" method
        def constantize_wrapper(camel_cased_word, &block)
          Serializer.extract(camel_cased_word, :priority).then { |item|
            block.call(item[:rest])
                 .then { |klass|
                   item[:priority] ? klass.with_priority(item[:priority].to_i) : klass
                 }
          }
        end
      end

      # Helper methods for workers
      module ClassMethods
        attr_accessor :resque_prioritize_priority

        # Returns worker without priority.
        # For jobs which does not have a priority - just returns itself.
        def without_priority
          resque_prioritize_priority ? superclass.without_priority : self
        end

        # Returns inherited class with stored priority
        def with_priority(priority)
          # in cases when someone call twice `Worker.with_priority(10).with_priority(20)`
          PriorityWrapper.new(without_priority, priority).call
        end
      end
    end
  end
end
