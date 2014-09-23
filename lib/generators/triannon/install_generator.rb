require 'rails/generators'

module Triannon
  class Install < Rails::Generators::Base
    def inject_Triannon_routes
      route "mount Triannon::Engine, at: 'annotations'"
    end
  end
end
