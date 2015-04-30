module Triannon

  class RootAnnotationCreator

    # Creates an LDP Container to hold all the annotations
    # Called from config/initializers/root_annotation_container.rb during app bootup
    # @return [Boolean] true if the root container was created, false if the container already exists or if there were issues
    def self.create
      uber_container_url = "#{Triannon.config[:ldp]['url']}/#{Triannon.config[:ldp]['uber_container']}"
      conn = Faraday.new url: uber_container_url
      resp = conn.head
      unless resp.status == 404 || resp.status == 410
        puts "Root annotation resource already exists."
        return false
      end

      uri = RDF::URI.new uber_container_url
      conn = Faraday.new url: uri.parent.to_s
      slug = uri.to_s.split('/').last

      resp = conn.post do |req|
        req.headers['Content-Type'] = 'text/turtle'
        req.headers['Slug'] = slug
      end

      if resp.status == 201
        puts "Created root annotation container #{uber_container_url}"
        return true
      else
        puts "Unable to create root annotation container #{uber_container_url}"
        return false
        # TODO: raise an exception if we get here?
      end
    end

  end
end
