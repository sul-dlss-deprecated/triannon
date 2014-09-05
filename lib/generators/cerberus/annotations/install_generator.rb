require 'rails/generators'

module Cerberus
  module Annotations
    class Install < Rails::Generators::Base
      def inject_cerberus_routes
        route "mount Cerberus::Annotations::Engine, at: 'annotations'"
      end
    end
  end
end
