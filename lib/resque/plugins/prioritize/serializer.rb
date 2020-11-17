# frozen_string_literal: true

module Resque
  module Plugins
    module Prioritize
      # Responsible for serialize and deserialize value by key into string.
      # Used to serialize variables over the class name. Returns result in format:
      #   %<original string>{{%<var_key>}:%<var_val>}
      module Serializer
        extend self

        VARIABLE_TEMPLATE = '{{%<key>s}:%<value>s}'
        VARIABLE_REGEXP = VARIABLE_TEMPLATE.sub('%<value>s', '([^}]+)')

        def serialize(original, **vars)
          vars.reduce(original.to_s) { |str, (key, val)|
            str + format(VARIABLE_TEMPLATE, key: key, value: val)
          }
        end

        # @return [Array<string without priority[String], priority[Numerical, Nil]>]
        def extract(serialized, *var_keys)
          var_keys.each_with_object(rest: serialized) { |var_key, result|
            next result.merge!(var_key.to_sym => nil) unless serialized.is_a?(String)

            extract_var(result.fetch(:rest), var_key).then { |rest, var_value|
              result.merge!(rest: rest, var_key.to_sym => var_value)
            }
          }
        end

        private

        # Removes serialized priority from serialized string
        # @return [Array<string without priority[String], priority[Numerical, Nil]>]
        def extract_var(string, var_key)
          string.match(/^(.+)#{format(VARIABLE_REGEXP, key: var_key)}(.*)$/i).then { |match|
            next [string] if match.nil?

            match.to_a
                 .then { |_, str, value, extra| [str + extra, value] }
          }
        end
      end
    end
  end
end
