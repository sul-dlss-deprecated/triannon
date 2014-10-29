
module Triannon

  # Loads an existing Annotation from the LDP server
  class LdpLoader

    def self.load key
      l = Triannon::LdpLoader.new key
      l.load_annotation
      l.load_bodies
      l.load_targets

      oa_graph = Triannon::LdpToOaMapper.ldp_to_oa l.annotation
      oa_graph
    end

    def self.find_all
      l = Triannon::LdpLoader.new
      l.find_all
    end

    attr_accessor :annotation

    def initialize key = nil
      @key = key
      @base_uri = Triannon.config[:ldp_url]
      @annotation = Triannon::AnnotationLdp.new
    end

    # load annotation object into @annotation's (our Triannon::AnnotationLdp object) graph
    def load_annotation
      load_object_into_annotation_graph(@key)
    end

    # load body objects into @annotation's (our Triannon::AnnotationLdp object) graph
    def load_bodies
      @annotation.body_uris.each { |body_uri|  
        body_obj_path = body_uri.to_s.split(@base_uri + '/').last
        load_object_into_annotation_graph(body_obj_path)
      }
    end

    # load target objects into @annotation's (our Triannon::AnnotationLdp object) graph
    def load_targets
      @annotation.target_uris.each { |target_uri| 
        target_obj_path = target_uri.to_s.split(@base_uri + '/').last
        load_object_into_annotation_graph(target_obj_path)
      }
    end
    
    # @return [Array<Triannon::Annotation>] an array of Triannon::Annotation objects with just the id set. Enough info to build the index page
    def find_all
      root_ttl = get_ttl
      objs = []

      g = RDF::Graph.new
      g.from_ttl root_ttl
      root_uri = RDF::URI.new @base_uri
      results = g.query [root_uri, RDF::LDP.contains, nil]
      results.each do |stmt|
        id = stmt.object.to_s.split('/').last
        objs << Triannon::Annotation.new(:id => id)
      end

      objs
    end

    protected

    # given a path to the back end storage url, retrieve the object from storage and load
    #  the triples (except storage specific triples) into the graph for @annotation, our Triannon::AnnotationLdp object
    # @param [String] path the path to the object, e.g. the pid, or  pid/t/target_pid
    def load_object_into_annotation_graph(path)
      @annotation.load_statements_into_graph(statements_from_ttl_minus_fedora(get_ttl path))
    end

    # gets object from back end storage as turtle serialization
    def get_ttl sub_path = nil
      resp = conn.get do |req|
        req.url "#{sub_path}" if sub_path
        req.headers['Accept'] = 'application/x-turtle'
      end
      resp.body
    end

    # turns turtle serialization into Array of RDF::Statements, removing fedora-specific triples
    #  (leaving LDP and OA triples)
    # @param [String] ttl a String containing RDF serialized as turtle
    # @return [Array<RDF::Statements>] the RDF statements represented in the ttl 
    def statements_from_ttl_minus_fedora ttl
      # RDF::Turtle::Reader.new(ttl).statements.to_a
      g = RDF::Graph.new.from_ttl(ttl)
      RDF::FCRepo4.remove_fedora_triples(g).statements
    end

    def conn
      @c ||= Faraday.new @base_uri
    end

  end

end
