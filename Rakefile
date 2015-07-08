begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

ZIP_URL = "https://github.com/projecthydra/hydra-jetty/archive/v8.3.1.zip"

require 'active_support/benchmarkable'
require 'jettywrapper'
require 'engine_cart/rake_task'

task :default => :ci

desc 'run the triannon specs'
task :ci do
  ENV['RAILS_ENV'] = 'test'
  Rake::Task['triannon:update_app'].invoke
  Rake::Task['spec'].invoke
end

load 'rails/tasks/statistics.rake'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

require 'rubocop/rake_task'
RuboCop::RakeTask.new

Dir.glob('lib/tasks/*.rake').each { |r| load r}

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

  desc 'update gems and engine cart app'
  task :update_app do
    # This project uses an engine cart app to run specs.  The engine cart
    # preparation modifies the root Gemfile so that it will include the engine
    # cart Gemfile, if it exists (by default, it's in ./spec/internal/Gemfile).
    # The engine cart Gemfile contains specific versions of gems that were last
    # available when the engine cart was generated.  To perform a complete
    # update, first remove the engine cart app.
    File.delete('Gemfile.lock')
    Rake::Task['engine_cart:clean'].invoke
    if ENV['RAILS_ENV'] == 'test'
      system 'bundle install --without :dev'
      # don't have the '--without' auto-persist
      system "sed -i -e '/BUNDLE_WITHOUT/d' .bundle/config"
    else
      system 'bundle install'
    end
    # Now generate the engine cart app again, but do not constrain it with
    # the root Gemfile.lock gemset while testing; the triannon.gemset should be
    # the only constraint on gems that are required for triannon; removing
    # Gemfile.lock allows third-party gems to be resolved as they would when
    # a third-party app includes triannon.  Any conflicts can be identified
    # in a development environment (anytime RAILS_ENV is != 'test').
    File.delete('Gemfile.lock') if ENV['RAILS_ENV'] == 'test'
    Rake::Task['engine_cart:generate'].invoke
    # Report the entire set of gems now available, including those required by
    # the engine cart app.
    system 'bundle show --paths'
  end

end # namespace triannon


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
