# frozen_string_literal: true

require 'resque'
require_relative 'prioritize/version'
require_relative 'prioritize/resque_extension'
require_relative 'prioritize/data_store_extension'

Resque.prepend Resque::Plugins::Prioritize::ResqueExtension
Resque::DataStore.prepend Resque::Plugins::Prioritize::DataStoreExtension

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
      PRIORITY_REGEXP = /\{\{priority\}:(\d+)\}/.freeze
      UUID_REGEXP = /\{\{uuid\}:([^}]+)\}/.freeze

      @prioritized_queue_postfix = '_prioritized'

      class << self
        attr_accessor :prioritized_queue_postfix

        def included(base)
          base.extend ClassMethods
        end
      end

      # Helper methods for workers
      module ClassMethods
        # Returns worker without priority.
        # For jobs which does not have a priority - just returns itself.
        def without_priority
          @resque_prioritize_priority ? superclass : self
        end

        # Returns inherited class with stored priority
        def with_priority(priority)
          # in cases when someone call twice `Worker.with_priority(10).with_priority(20)`
          original = without_priority

          # Produce an exact copy of the current worker's class, including all data,
          # but with @resque_prioritize_priority set. It is also stringified differently, as
          # "WorkerName{priority:10}", allowing redefined Resque deserializer to understand how to
          # process it.
          Class.new(original).tap do |inherited|
            inherited.instance_variable_set(:@resque_prioritize_priority, priority)

            original.instance_variables.each do |var|
              inherited.instance_variable_set(var, original.instance_variable_get(var))
            end

            # override stringify methods
            %i[to_s name inspect].each do |m|
              inherited.define_singleton_method(m) do
                "#{original.send(m)}{{priority}:#{@resque_prioritize_priority}}"
              end
            end

            # Check equality with two inherited class
            inherited.define_singleton_method(:==) do |other|
              other.to_s == inherited.to_s
            end
          end
        end
      end
    end
  end
end
