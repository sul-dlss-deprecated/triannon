$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "cerberus/annotations/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "cerberus-annotations"
  s.version     = Cerberus::Annotations::VERSION
  s.authors     = ["Chris Beer"]
  s.email       = ["cabeer@stanford.edu"]
  s.homepage    = "TODO"
  s.summary     = "TODO: Summary of Cerberus."
  s.description = "TODO: Description of Cerberus."
  s.license     = "Apache 2"

  s.files = Dir["{app,config,db,lib}/**/*", "Rakefile", "README.md"]

  s.add_dependency "rails", "~> 4.2.0.beta1"

  s.add_development_dependency "sqlite3"
  s.add_development_dependency "rspec", "~> 3.0"
  s.add_development_dependency "engine_cart", "~> 0.4"
end
