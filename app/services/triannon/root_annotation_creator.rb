module Triannon

  class RootAnnotationCreator

    # Creates an LDP Container to hold all the annotations
    # Called from config/initializers/root_annotation_container.rb during app bootup
    # @return [Boolean] true if the root container was created, false if the container already exists or if there were issues
    def self.create
    	Triannon::LdpWriter.create_basic_container(nil, Triannon.config[:ldp]['uber_container'])
    end
  end
end
