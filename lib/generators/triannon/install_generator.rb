require 'rails/generators'

module Triannon
  class Install < Rails::Generators::Base
    def inject_Triannon_routes
      route "mount Triannon::Engine, at: 'annotations'"
    end

    def create_triannon_yml_file
      default_yml =<<-YML
development:
  ldp_url: http://localhost:8983/fedora/rest/anno
  triannon_base_url: http://your.triannon-server.com
test: &test
  ldp_url: http://localhost:8983/fedora/rest/anno
  triannon_base_url: http://your.triannon-server.com
production:
  ldp_url:
  triannon_base_url:
      YML
      create_file 'config/triannon.yml', default_yml
    end
  end
end
