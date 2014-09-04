begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

require 'rdoc/task'

RDoc::Task.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Cerberus'
  rdoc.options << '--line-numbers'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

require 'engine_cart/rake_task'
task :ci => ['engine_cart:generate'] do
  # run the tests
  Rake::Task['spec'].invoke
end


load 'rails/tasks/statistics.rake'

require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task :default => :ci

Bundler::GemHelper.install_tasks

