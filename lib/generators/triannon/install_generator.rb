require 'rails/generators'

module Triannon
  class Install < Rails::Generators::Base
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
  end
end
