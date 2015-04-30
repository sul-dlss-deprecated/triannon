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
  ldp:
    url: http://localhost:8983/fedora/rest
    # uber_container:  LDP BasicContainer that will have anno containers as members
    uber_container:  anno
    # anno_containers:  LDP BasicContainers that will have individual annotations as members
    #  the container names here will also map to paths in the triannon url, e.g.
    #  "foo" here will mean you add a foo anno by POST to http://your.triannon-server.com/annotations/foo
    #  and you get the foo anno by GET to http://your.triannon-server.com/annotations/foo/(anno_uuid)
    anno_containers:
      - foo
      - blah
  solr_url: http://localhost:8983/solr/triannon
  triannon_base_url: http://your.triannon-server.com/annotations/
  max_solr_retries: 5
  base_sleep_seconds: 1
  max_sleep_seconds: 5
test: &test
  ldp:
    url: http://localhost:8983/fedora/rest
    uber_container:  anno
    anno_containers:
      - foo
      - blah
  solr_url: http://localhost:8983/solr/triannon
  triannon_base_url: http://your.triannon-server.com/annotations/
production:
  ldp:
    url:
    uber_container:  anno
    anno_containers:
      - foo
      - blah
  solr_url:
  triannon_base_url:
      YML
      create_file 'config/triannon.yml', default_yml
    end

    def add_linked_data_caching
      gem 'rest-client'
      gem 'rack-cache'
      gem 'rest-client-components'

      Bundler.with_clean_env do
        run "bundle install"
      end

      copy_file 'rest_client.rb', 'config/initializers/rest_client.rb'
    end
  end
end
