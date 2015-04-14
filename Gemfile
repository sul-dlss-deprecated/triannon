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
    #  (perhaps not needed forever)
    #
    # as of sometime between 2015-04-09 and 2015-04-13, we get
    # bundler error when running rake ci w/o generating testing app first (e.g. travis):
    #
    # Bundler could not find compatible versions for gem "tilt":
    #  In snapshot (Gemfile.lock):
    #    tilt (2.0.1)
    #
    #  In Gemfile:
    #    sass-rails (~> 5.0) ruby depends on
    #      tilt (~> 1.1) ruby
    #
    # this means omewhere in the triannon dependencies (2nd level or lower), the version
    #  from the triannon dependencies conflicts with the rails application's dependencies on sass
    #  rails v4.2.1 / sass-rails 5.0.3 / haml
    #
    # magically, the following line fixes this problem.
    gem 'tilt'
  end
