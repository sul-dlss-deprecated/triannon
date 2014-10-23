begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

ZIP_URL = "https://github.com/sul-dlss/hydra-jetty/archive/fedora-4/edge.zip"

require 'active_support/benchmarkable'
require 'jettywrapper'

require 'rdoc/task'

RDoc::Task.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Triannon'
  rdoc.options << '--line-numbers'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

require 'engine_cart/rake_task'
desc 'run the triannon specs'
task :ci => ['engine_cart:generate', 'jetty:clean'] do
  # run the tests
  RAILS_ENV = 'test'
  jetty_params = Jettywrapper.load_config.merge({:jetty_home => File.expand_path(File.dirname(__FILE__) + '/jetty')})
  Jettywrapper.wrap(jetty_params) do
    Rake::Task['spec'].invoke
  end
end

namespace :triannon do
  desc 'run test rails app w triannon and jetty'
  task :server_jetty do
    jetty_params = Jettywrapper.load_config.merge({:jetty_home => File.expand_path(File.dirname(__FILE__) + '/jetty')})
    Jettywrapper.wrap(jetty_params) do
      within_test_app do
        system "rails s"
      end
    end
  end

  desc 'run test rails app w triannon but no jetty'
  task :server_no_jetty do
    within_test_app do
      system "rails s"
    end
  end
  desc 'run test rails app w triannon but no jetty'
  task :server => :server_no_jetty

  desc 'run test rails console w triannon'
  task :console_jetty do
    jetty_params = Jettywrapper.load_config.merge({:jetty_home => File.expand_path(File.dirname(__FILE__) + '/jetty')})
    Jettywrapper.wrap(jetty_params) do
      within_test_app do
        system "rails c"
      end
    end
  end

  desc 'run test rails console w triannon but no jetty'
  task :console_no_jetty do
    within_test_app do
      system "rails c"
    end
  end
  desc 'run test rails console w triannon but no jetty'
  task :console => :console_no_jetty

end


load 'rails/tasks/statistics.rake'

require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task :default => :ci

Bundler::GemHelper.install_tasks
