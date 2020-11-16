# frozen_string_literal: true

module Resque
  module Plugins
    module Prioritize
      # Extension of resque class
      module ResqueSchedulerUtilExtension
        def self.prepended(base)
          class << base
            prepend ClassMethods
          end
        end

        # Class methods to override base Resque module
        module ClassMethods
          # Returns klass with priority for cases, when priority was serialized.
          def constantize(camel_cased_word)
            Resque::Plugins::Prioritize
              .constantize_wrapper(camel_cased_word) { |name| super(name) }
          end
        end
      end
    end
  end
end
