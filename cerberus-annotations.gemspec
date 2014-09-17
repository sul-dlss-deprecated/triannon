$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "cerberus/annotations/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "cerberus-annotations"
  s.version     = Cerberus::Annotations::VERSION
  s.authors     = ["Chris Beer"]
  s.email       = ["cabeer@stanford.edu"]
  s.summary     = "Open Annotation demonstrator for LD4L"
  s.license     = "Apache 2"

  s.files = Dir["{app,config,db,lib}/**/*", "Rakefile", "README.md"]

  s.add_dependency "rails", "~> 4.2.0.beta1"
  s.add_dependency "linkeddata"
  s.add_dependency "rdf-open_annotation"
  s.add_dependency "open-uri-cached"
  s.add_dependency "bootstrap-sass"
  s.add_dependency "sass-rails", ">= 5.0.0.beta1"
  
  s.add_development_dependency "sqlite3"
  s.add_development_dependency "rspec", "~> 3.0"
  s.add_development_dependency "rspec-rails", "~> 3.0"
  s.add_development_dependency "engine_cart", "~> 0.4"
  s.add_development_dependency "jettywrapper"
  s.add_development_dependency "capybara"
end
