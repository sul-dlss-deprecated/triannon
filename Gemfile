source 'https://rubygems.org'

# Declare your gem's dependencies in triannon.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
gemspec

# Declare any dependencies that are still in development here instead of in
# your gemspec. These might include edge Rails or gems from your path or
# Git. Remember to move these dependencies to your gemspec before releasing
# your gem to rubygems.org.

# To use a debugger
gem 'pry-byebug', group: [:development, :test]

  file = File.expand_path("Gemfile", ENV['ENGINE_CART_DESTINATION'] || ENV['RAILS_ROOT'] || File.expand_path("../spec/internal", __FILE__))
  if File.exists?(file)
    puts "Loading #{file} ..." if $DEBUG # `ruby -d` or `bundle -v`
    instance_eval File.read(file)
  else
    # we get here when we haven't yet generated the testing app via engine_cart

    # as of rails v 4.2.0.rc1 (but perhaps not needed forever):
    # somewhere in the triannon dependencies (2nd level or lower) is requiring sass;  the version from 
    #  the triannon dependencies conflicts with the rails application's dependencies on sass
    # magically, the following line fixes this problem.
    gem 'sass-rails'
  end
