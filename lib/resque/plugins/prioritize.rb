# frozen_string_literal: true

require 'resque'
require_relative 'prioritize/version'

module Resque
  module Plugins
    # Plugin to ensure Resque job's priority.
    module Prioritize
    end
  end
end
