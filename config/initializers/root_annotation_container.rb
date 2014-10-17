
def root_container_create
  return if(ENV['CI'] && !ENV['RSPEC_RUNNING'])

  Triannon::RootAnnotationCreator.create if File.exists? Triannon.triannon_file
end

root_container_create
