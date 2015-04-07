require 'rails/generators'

module Triannon
  class Install < Rails::Generators::Base
    source_root File.expand_path('../templates', __FILE__)

    def inject_Triannon_routes
      route "mount Triannon::Engine, at: ''"
    end

    def create_triannon_yml_file
      default_yml =<<-YML
development:
  ldp_url: http://localhost:8983/fedora/rest/anno
  solr_url: http://localhost:8983/solr/triannon
  triannon_base_url: http://your.triannon-server.com/annotations/
  max_solr_retries: 5
  base_sleep_seconds: 1
  max_sleep_seconds: 5
test: &test
  ldp_url: http://localhost:8983/fedora/rest/anno
  solr_url: http://localhost:8983/solr/triannon
  triannon_base_url: http://your.triannon-server.com/annotations/
production:
  ldp_url:
  solr_url:
  triannon_base_url:
      YML
      create_file 'config/triannon.yml', default_yml
    end

    def add_linked_data_caching
#      gem 'rest-client'
#      gem 'rack-cache'
#      gem 'rest-client-components'
      gem 'faraday'
      gem 'faraday_middleware'
      gem 'faraday-http-cache'
      gem 'http_logger'

      Bundler.with_clean_env do
        run "bundle install"
      end

#      copy_file 'rest_client.rb', 'config/initializers/rest_client.rb'
      copy_file 'rdf.rb', 'config/initializers/rdf.rb'
    end
  end
end
