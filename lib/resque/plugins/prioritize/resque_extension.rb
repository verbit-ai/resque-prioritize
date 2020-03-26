# frozen_string_literal: true

module Resque
  module Plugins
    module Prioritize
      # Extension of resque class
      module ResqueExtension
        def self.prepended(base)
          class << base
            prepend ClassMethods
          end
        end

        # Class methods to override base Resque module
        module ClassMethods
          # Returns klass with priority for cases, when priority was serialized.
          def constantize(camel_cased_word)
            return super unless camel_cased_word.instance_of?(String)

            match = camel_cased_word.match(/^(.+)#{PRIORITY_REGEXP}(.*)$/) or return super

            match.to_a.then { |_, name, priority, extra|
              # extra - to be sure that other plugins, which also could use class serialization,
              # will not be broken
              super(name + extra).with_priority(priority.to_i)
            }
          end
        end
      end
    end
  end
end
