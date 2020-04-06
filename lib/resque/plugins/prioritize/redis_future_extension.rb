# frozen_string_literal: true

module Resque
  module Plugins
    module Prioritize
      # We change type of redis queue from list to zset. But base redis methods for zset not works
      # fine for redis piplined blocks. However we should to work, to not break a basic behaviour
      # of Resque inside redis pipelined blocks.
      module RedisFutureExtension
        # Redis#zpopmax call `members.first` when count is not more than 1. When we work inside
        # pipelined blocks we have an error. So, here we just move this action into transformation
        # `@transformation` variable
        def first
          add_transformation(&:first)
          self
        end

        # For queue_size methods
        def to_i
          add_transformation(&:to_i)
          self
        end

        # Add transformation to value before returns it to user.
        # @transformation - is a callback which calls to transform result value before return
        # to user. It could be nil. So, I just add new transformation to this variable.
        #
        # NOTE: See Redis::Future#_set method for understanding of @transformation variable usage.
        def add_transformation(&block)
          @transformation ? @transformation >>= block : @transformation = block
        end
      end
    end
  end
end
