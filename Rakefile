begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

ZIP_URL = "https://github.com/sul-dlss/hydra-jetty/archive/fedora-4/edge.zip"

require 'active_support/benchmarkable'
require 'jettywrapper'

require 'engine_cart/rake_task'
desc 'run the triannon specs'
task :ci => 'engine_cart:generate' do
  RAILS_ENV = 'test'
  Rake::Task['spec'].invoke
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


  desc "set up triannon solr in test jetty"
  task :solr_jetty_setup do
    `cp -r config/solr/triannon-core jetty/solr`
    `cp config/solr/solr.xml jetty/solr`
  end
end


load 'rails/tasks/statistics.rake'

require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task :default => :ci


desc "Generate RDoc with YARD"
task :doc => ['doc:generate']

namespace :doc do
  begin
    require 'yard'
    require 'yard/rake/yardoc_task'

    YARD::Rake::YardocTask.new(:generate) do |yt|
      yt.files   =  Dir.glob(File.join('app', '**', '*.rb')) +
                    Dir.glob(File.join('lib', '*.rb')) +
                    Dir.glob(File.join('lib', '**', '*.rb'))

      yt.options = ['--output-dir', 'rdoc', '--readme', 'README.md', '--files', 'LICENSE',
                    '--protected', '--private', '--title', 'Triannon', '--exclude', 'triannon_vocab']
    end
  rescue LoadError
    desc "Generate RDoc with YARD"
    task :generate do
      abort "Please install the YARD gem to generate rdoc."
    end
  end

  desc "Remove generated documenation"
  task :clean do
    rm_r 'rdoc' if File.exist?('rdoc')
  end
end
Bundler::GemHelper.install_tasks
