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

group :test do
  file = File.expand_path("Gemfile", ENV['ENGINE_CART_DESTINATION'] || ENV['RAILS_ROOT'] || File.expand_path("../spec/internal", __FILE__))
  if File.exists?(file)
    puts "Loading #{file} ..." if $DEBUG # `ruby -d` or `bundle -v`
    instance_eval File.read(file)
  else
    gem 'rails', ENV['RAILS_VERSION'] if ENV['RAILS_VERSION']

    if ENV['RAILS_VERSION'] and ENV['RAILS_VERSION'] =~ /^4.2/
      gem 'responders', "~> 2.0"
      gem 'sass-rails', ">= 5.0"
    else
      gem 'sass-rails', "< 5.0"
    end
  end
end

