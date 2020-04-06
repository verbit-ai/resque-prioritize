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
          class PipelineNotSupported < StandardError; end

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
            handle_pipeline(@redis.zpopmax(redis_key_for_queue(queue))) { |item, _|
              without_uuid(item)
            }
          end

          # Get the number of items in the queue
          def z_queue_size(queue)
            handle_pipeline(@redis.zcount(redis_key_for_queue(queue), 0, Float::INFINITY), &:to_i)
          end

          def z_everything_in_queue(queue)
            handle_pipeline(@redis.zrevrange(redis_key_for_queue(queue), 0, -1)) { |items|
              items.map(&method(:without_uuid))
            }
          end

          # Remove data from the queue, if it's there, returning the number of removed elements
          # Not so very fast method. But because of uuid in the zset items we could not to make it
          # faster.
          # Usaually this method uses manually, so speed - not so critical.
          #
          # NOTE: placing uuids into special key - not a good idea. We could to remove queue,
          # for example, and we lose symchronize between two lists. So speed increase in this case
          # will break a logic.
          #
          # NOTE: We need at least two requests to redis, so, we could not to make it inside
          # pipeline block
          def z_remove_from_queue(queue, data)
            raise PipelineNotSupported if @redis.client.is_a?(Redis::Pipeline)

            priority = extract_priority(data)
            z_item = @redis.zrevrange(redis_key_for_queue(queue), 0, -1).find do |item|
              (priority && item.include?(data)) || \
                (item.include?(data[/"class":"[^ "]+/]) && item.include?(data[/"args":.+/]))
            end or return
            @redis.zrem(redis_key_for_queue(queue), z_item)
          end

          # parent method returns object, when count eq 1, and array, whe count is more.
          def z_list_range(key, start = 0, count = 1)
            handle_pipeline(@redis.zrevrange(key, start, start + count - 1)) { |object|
              list = Array(object).map(&method(:without_uuid))

              next list.first if count == 1

              list
            }
          end

          # Hack to allow gem work inside Redis Pipilened block.
          # NOTE: See Resque::Plugins::Prioritize::RedisFutureExtension#add_transformation
          def handle_pipeline(object, &block)
            object.is_a?(Redis::Future) ? object.add_transformation(&block) : block.call(object)
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
          def prioritized?(queue)
            queue = queue.to_s
            if @redis.client.is_a?(Redis::Pipeline)
              # To prevent unexpected values inside result block
              return queue.include?(Prioritize.prioritized_queue_postfix)
            end

            queue = queue.include?('queue:') ? queue : redis_key_for_queue(queue)
            queue_type = @redis.type(queue)
            # With type check we will handle the cases when queue postfix was renamed during
            # the work. So, it is the better practise. However, it doesn't work for empty queues.
            queue_type == 'zset' || \
              # In case when queue is empty on type check, but not empty on the action (pop, in
              # the most cases), we could have an error.
              # So, in that cases we should check queue type by name.
              (queue_type == 'none' && queue.include?(Prioritize.prioritized_queue_postfix))
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
