# frozen_string_literal: true

source 'https://rubygems.org'

ruby '>= 2.6'

# Specify your gem's dependencies in resque-prioritize.gemspec
gemspec

group :development do
  gem 'rubocop'
  gem 'rubocop-rspec'
end

group :development, :test do
  gem 'pry'
  gem 'resque-scheduler' # it is not neccessary plugin. But if it present - we should extend it.
  gem 'rspec', '~> 3.0'
  gem 'rspec-its' # its(:foo) syntax
  gem 'saharspec', '~> 0.0.7' # some syntactic sugar for RSpec
end
