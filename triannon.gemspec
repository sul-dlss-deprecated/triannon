$:.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'triannon/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'triannon'
  s.version     = Triannon::VERSION
  s.authors     = ['Naomi Dushay', 'Willy Mene']
  s.email       = ['ndushay@stanford.edu', 'wmene@stanford.edu']
  s.summary     = 'Rails engine for working with OpenAnnotations stored in Fedora4'
  s.license     = 'Apache-2.0'
  s.homepage    = 'https://github.com/sul-dlss/triannon'

  s.files = Dir['{app,config,db,lib}/**/*', 'Rakefile', 'README.md']

  s.add_dependency 'rails', '~> 4.2'
  s.add_dependency 'linkeddata'
  s.add_dependency 'oa-graph'
  s.add_dependency 'rdf-iiif'  # RDF vocab for IIIF
  s.add_dependency 'bootstrap-sass'
  s.add_dependency 'faraday' # for writing to LDP store
  s.add_dependency 'rsolr'
  s.add_dependency 'retries' # for writing to Solr

  s.add_development_dependency 'rspec', '~> 3.1.0' # bug with graph_spec #remove_predicate_and_its_object_statements for 3.2.0
  s.add_development_dependency 'rspec-rails', '~> 3.1.0' # bug with graph_spec #remove_predicate_and_its_object_statements for 3.2.0
  s.add_development_dependency 'engine_cart'
  s.add_development_dependency 'jettywrapper'
  s.add_development_dependency 'capybara'
  s.add_development_dependency 'vcr'
  s.add_development_dependency 'webmock'
  s.add_development_dependency 'coveralls'
  s.add_development_dependency 'yard' # for documentation
  s.add_development_dependency 'rubocop'
  s.add_development_dependency 'rubocop-rspec'
  s.add_development_dependency 'rest-client' # for caching jsonld context docs
  s.add_development_dependency 'rest-client-components' # for caching jsonld context docs
  s.add_development_dependency 'rack-cache' # for caching jsonld context docs
end
