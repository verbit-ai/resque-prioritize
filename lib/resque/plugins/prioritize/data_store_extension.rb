# frozen_string_literal: true

require 'securerandom'

module Resque
  module Plugins
    module Prioritize
      # Extension for Resque::DataStore class
      # Separate prioritized jobs from not prioritized.
      # Adding `Resque::Plugins::Prioritize.prioritized_queue_postfix` to prioritized queues
      # Use ZSet redis type for prioritized queues
      module DataStoreExtension
        def self.prepended(base)
          base::QueueAccess.prepend QueueAccessExtension
        end

        # Override default QueueAccess to work with redis Zset instead of redis list
        module QueueAccessExtension
          def push_to_queue(queue, encoded_item)
            priority = extract_priority(encoded_item)
            priority ? z_push_to_queue(z_queue(queue), encoded_item, priority) : super
          end

          # Pop whatever is on queue
          def pop_from_queue(queue)
            prioritized?(queue) ? z_pop_from_queue(queue) : super
          end

          # Get the number of items in the queue
          def queue_size(queue)
            prioritized?(queue) ? z_queue_size(queue) : super
          end

          def everything_in_queue(queue)
            prioritized?(queue) ? z_everything_in_queue(queue) : super
          end

          # Remove data from the queue, if it's there, returning the number of removed elements
          def remove_from_queue(queue, data)
            prioritized?(queue) ? z_remove_from_queue(queue, data) : super
          end

          def list_range(key, start = 0, count = 1)
            prioritized?(key) ? z_list_range(key, start, count) : super
          end

          private

          def z_push_to_queue(queue, encoded_item, priority)
            @redis.pipelined do
              watch_queue(queue)
              @redis.zadd(redis_key_for_queue(queue), priority, with_uuid(encoded_item))
            end
          end

          def z_pop_from_queue(queue)
            item, _priority = @redis.zpopmax(redis_key_for_queue(queue))
            without_uuid(item)
          end

          # Get the number of items in the queue
          def z_queue_size(queue)
            @redis.zcount(redis_key_for_queue(queue), 0, Float::INFINITY).to_i
          end

          def z_everything_in_queue(queue)
            @redis.zrevrange(redis_key_for_queue(queue), 0, -1).map(&method(:without_uuid))
          end

          # Remove data from the queue, if it's there, returning the number of removed elements
          # Not so very fast method. But because of uuid in the zset items we could not to make it
          # faster.
          # Usaually this method uses manually, so speed - not so critical.
          #
          # NOTE: placing uuids into special key - not a good idea. We could to remove queue,
          # for example, and we lose symchronize between two lists. So speed increase in this case
          # will break a logic.
          def z_remove_from_queue(queue, data)
            priority = extract_priority(data)
            z_item = @redis.zrevrange(redis_key_for_queue(queue), 0, -1).find do |item|
              (priority && item.include?(data)) || \
                (item.include?(data[/"class":"[^ "]+/]) && item.include?(data[/"args":.+/]))
            end or return
            @redis.zrem(redis_key_for_queue(queue), z_item)
          end

          # parent method returns object, when count eq 1, and array, whe count is more.
          def z_list_range(key, start = 0, count = 1)
            list = Array(@redis.zrevrange(key, start, start + count - 1))
                   .map(&method(:without_uuid))

            return list.first if count == 1

            list
          end

          # zset store only uniq elements. But redis queue could have few same elements.
          # So, we should add some uuid to every element
          def with_uuid(encoded_item, uuid = SecureRandom.uuid)
            encoded_item.match?(UUID_REGEXP) ? encoded_item : "#{encoded_item}{{uuid}:#{uuid}}"
          end

          # Remove uuid from item. See `with_uuid` method
          def without_uuid(item)
            item&.sub(UUID_REGEXP, '')
          end

          def extract_priority(encoded_item)
            encoded_item.match(PRIORITY_REGEXP)&.[](1)&.to_i
          end

          # Check by type. If type is zset - queue is prioritized.
          # In other cases - work like it was before
          #
          # NOTE: checking by type - is better practise, that by queue name.
          def prioritized?(queue)
            queue = queue.to_s.include?('queue:') ? queue : redis_key_for_queue(queue)
            @redis.type(queue) == 'zset'
          end

          def z_queue(queue)
            if queue.to_s.include?(Prioritize.prioritized_queue_postfix)
              queue
            else
              "#{queue}#{Prioritize.prioritized_queue_postfix}"
            end
          end
        end
      end
    end
  end
end
