# Resque::Plugins::Prioritize

<!-- MarkdownTOC -->

- [Introduction](#introduction)
- [Requirements](#requirements)
- [Installation](#installation)
- [Global Configuration](#global-configuration)
  - [Enable plugin](#enable-plugin)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)

<!-- /MarkdownTOC -->

## Introduction

The goal of this gem is to prioritize resque jobs inside queue. We do this by creating special separated queue (by adding `_prioritized` postfix, however it is configurable) for jobs with priority. New queue have ZSet redis type. To pop jobs from this queue we use `redis.zpopmax` method.

However, base behaviour of resque queues will not change. Even if you include the plugin. Only new prioritized queus, which was created by enqueue resque workers with priority by `Resque.enqueue(TestWorker.with_priority(10), *args)` will have a new behaviour.

## Requirements

- Resque `~> 2.0.0`
- Ruby `>= 2.3`

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'resque-prioritize'
```

And then execute:

```bash
bundle
```

Or install it yourself as:

```bash
gem install resque-prioritize
```

## Global Configuration

You can change default prioritized queue postfix by
```ruby
Resque::Plugins::Prioritize.prioritized_queue_postfix = '_custom_postfix'
```
By default it is equal `_prioritized`

### enable plugin

```ruby
class TestWorker
  include Resque::Plugins::Prioritize

  def self.perform(*args)
  end
end
```

All workers and their descendants, which include this plugin, will already have a prioritize system.

You can use it
``` ruby
Resque.enqueue(TestWorker.with_priority(10), *args)
```

If, for some reason, you need to remove priority from the class, you could use `without_priority` method:
```ruby
TestWorker.with_priority(10).without_priority # -> TestWorker
```

If you will call `without_priority` for entry class, it will returns that class:
```ruby
TestWorker.without_priority # -> TestWorker
```

## Testing

You should to run resque workers:

`QUEUE=* COUNT=1 bundle exec rake resque:workers`

And after it:

`bundle exec rake spec`

## Contributing

1. Fork it
1. Create your feature branch (`git checkout -b my-new-feature`)
1. Commit your changes (`git commit -am 'Add some feature'`)
1. Push to the branch (`git push origin my-new-feature`)
1. Create new Pull Request

Bug reports and pull requests are welcome on GitHub at https://github.com/verbit/resque-prioritize. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
