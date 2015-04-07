source 'https://rubygems.org'

# Declare your gem's dependencies in triannon.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
gemspec

# Declare any dependencies that are still in development here instead of in
# your gemspec. These might include edge Rails or gems from your path or
# Git. Remember to move these dependencies to your gemspec before releasing
# your gem to rubygems.org.

# TODO: temporary - waiting for vcr release > v2.9.3
# use master branch of vcr due to incompatibility with faraday 0.9.0
#   (https://github.com/vcr/vcr/pull/439  in master, but not in released gem)
# Error when running specs:
# Failure/Error: Unable to find matching line from backtrace
#   NoMethodError:
#     undefined method `to_hash' for nil:NilClass
# .rvm/gems/ruby-2.1.5@triannon/gems/vcr-2.9.3/lib/vcr/structs.rb:497:in `to_hash'
# .rvm/gems/ruby-2.1.5@triannon/gems/vcr-2.9.3/lib/vcr/cassette.rb:249:in `block in interactions_to_record'
# .rvm/gems/ruby-2.1.5@triannon/gems/vcr-2.9.3/lib/vcr/cassette.rb:249:in `map'
# .rvm/gems/ruby-2.1.5@triannon/gems/vcr-2.9.3/lib/vcr/cassette.rb:249:in `interactions_to_record'
# .rvm/gems/ruby-2.1.5@triannon/gems/vcr-2.9.3/lib/vcr/cassette.rb:116:in `serializable_hash'
# .rvm/gems/ruby-2.1.5@triannon/gems/vcr-2.9.3/lib/vcr/cassette.rb:256:in `write_recorded_interactions_to_disk'
# .rvm/gems/ruby-2.1.5@triannon/gems/vcr-2.9.3/lib/vcr/cassette.rb:65:in `eject'
# .rvm/gems/ruby-2.1.5@triannon/gems/vcr-2.9.3/lib/vcr.rb:149:in `eject_cassette'
# .rvm/gems/ruby-2.1.5@triannon/gems/vcr-2.9.3/lib/vcr/test_frameworks/rspec.rb:40:in `block (2 levels) in configure!'
gem "vcr", :git => 'https://github.com/vcr/vcr.git'


# To use a debugger
gem 'pry-byebug', group: [:development, :test]

  file = File.expand_path("Gemfile", ENV['ENGINE_CART_DESTINATION'] || ENV['RAILS_ROOT'] || File.expand_path("../spec/internal", __FILE__))
  if File.exists?(file)
    puts "Loading #{file} ..." if $DEBUG # `ruby -d` or `bundle -v`
    instance_eval File.read(file)
  end
