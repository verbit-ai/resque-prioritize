# frozen_string_literal: true

module Resque
  module Plugins
    module Prioritize
      # Wrap the worker with the priority.
      # Produce an exact copy of the current worker's class, including all data, but with
      # @resque_prioritize_priority instance variable, which stores the priority of worker. It is
      # also stringified differently, as "WorkerName{priority:10}", allowing redefined Resque
      # deserializer to understand how to process it.
      class PriorityWrapper
        extend Forwardable

        class ValidationError < StandardError; end

        def initialize(original, priority)
          @original = original
          @priority = priority
        end

        def call
          validate!

          Class.new(original)
               .tap(&method(:install_priority))
               .tap(&method(:copy_instance_variables))
               .tap(&method(:override_stringify_methods))
               .tap(&method(:setup_equality_check))
        end

        private

        attr_reader :original, :priority

        def_delegator :'Resque::Plugins::Prioritize', :to_prioritized_queue

        def validate!
          original.is_a?(Class) or
            invalid("Incorrect original. Should be Class, but it's #{original.class}")
          priority or invalid('Priority should be present')
        end

        def install_priority(inherited)
          inherited.resque_prioritize_priority = priority
        end

        def copy_instance_variables(inherited)
          original.instance_variables.each do |var|
            value = original.instance_variable_get(var)
            # Needs to write a new queue name, with a prioritized postfix
            value = to_prioritized_queue(value) if var == :@queue

            inherited.instance_variable_set(var, value)
          end
        end

        def override_stringify_methods(inherited)
          %i[to_s name inspect].each do |m|
            # Needs to init local variable, because othervise we will not have an access to
            # service methods in the `define_singleton_method` body
            original_str = original.public_send(m)
            installed_priority = priority

            inherited.define_singleton_method(m) do
              Serializer.serialize(original_str, priority: installed_priority)
            end
          end
        end

        def setup_equality_check(inherited)
          inherited.define_singleton_method(:==) do |other|
            other.to_s == inherited.to_s
          end
        end

        def invalid(message)
          raise ValidationError, message
        end
      end
    end
  end
end
