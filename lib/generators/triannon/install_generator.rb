require 'rails/generators'

module Triannon
  class Install < Rails::Generators::Base
    def inject_Triannon_routes
      route "mount Triannon::Engine, at: 'annotations'"
    end

    def create_ldp_yml_file
      default_ldp_yml =<<-YML
development:
  url: http://localhost:8080/rest/anno
test: &test
  url: http://localhost:8080/rest/anno
production:
  url:
      YML
      create_file 'config/ldp.yml', default_ldp_yml
    end
  end
end
