require_relative '../../app/services/triannon/root_annotation_creator'

namespace :triannon do
  desc "Create the root annotation container"
  task :create_root_container do
    unless File.exists? Triannon.triannon_file
      puts "Triannon config file missing: #{Triannon.triannon_file}"
    end
    Triannon::RootAnnotationCreator.create
  end
end
