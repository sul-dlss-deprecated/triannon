
module Triannon

  # Loads an existing Annotation from the LDP server
  class LdpLoader


    # @param [String] id the unique id of the annotation.  Can include base_uri prefix or omit it.
    def self.load id
      l = Triannon::LdpLoader.new id
      l.load_anno_container
      l.load_bodies
      l.load_targets

      oa_graph = Triannon::LdpToOaMapper.ldp_to_oa l.ldp_annotation
      oa_graph
    end

    # @deprecated was needed by old annotations#index action, which now redirects to search (2015-04)
    def self.find_all
      l = Triannon::LdpLoader.new
      l.find_all
    end

    attr_accessor :ldp_annotation

    # @param [String] id the unique id of the annotation.  Can include base_uri prefix or omit it.
    def initialize id = nil
      @id = id
      @base_uri = "#{Triannon.config[:ldp]['url']}/#{Triannon.config[:ldp]['uber_container']}"
      @ldp_annotation = Triannon::AnnotationLdp.new
    end

    # load annotation container object into @ldp_annotation's (our Triannon::AnnotationLdp object) graph
    def load_anno_container
      load_object_into_annotation_graph(@id)
    end

    # load body objects into @ldp_annotation's (our Triannon::AnnotationLdp object) graph
    def load_bodies
      @ldp_annotation.body_uris.each { |body_uri|
        body_obj_path = body_uri.to_s.split(@base_uri + '/').last
        load_object_into_annotation_graph(body_obj_path)
      }
    end

    # load target objects into @ldp_annotation's (our Triannon::AnnotationLdp object) graph
    def load_targets
      @ldp_annotation.target_uris.each { |target_uri|
        target_obj_path = target_uri.to_s.split(@base_uri + '/').last
        load_object_into_annotation_graph(target_obj_path)
      }
    end

    # @return [Array<Triannon::Annotation>] an array of Triannon::Annotation objects with just the id set. Enough info to build the index page
    # @deprecated was needed by old annotations#index action, which now redirects to search (2015-04).
    def find_all
      root_ttl = get_ttl
      objs = []

      g = RDF::Graph.new
      g.from_ttl root_ttl
      root_uri = RDF::URI.new @base_uri
      results = g.query [root_uri, RDF::Vocab::LDP.contains, nil]
      results.each do |stmt|
        id = stmt.object.to_s.split('/').last
        objs << Triannon::Annotation.new(:id => id)
      end

      objs
    end

    protected

    # given a path to the back end storage url, retrieve the object from storage and load
    #  the triples (except storage specific triples) into the graph for @ldp_annotation, our Triannon::AnnotationLdp object
    # @param [String] path the path to the object, e.g. the pid, or  pid/t/target_pid
    def load_object_into_annotation_graph(path)
      @ldp_annotation.load_statements_into_graph(statements_from_ttl_minus_fedora(get_ttl path))
    end

    # gets object from back end storage as turtle serialization
    def get_ttl sub_path = nil
      resp = conn.get do |req|
        req.url "#{sub_path}" if sub_path
        req.headers['Accept'] = 'application/x-turtle'
      end
      if resp.status.between?(400, 600)
        raise Triannon::LDPStorageError.new("error getting #{sub_path} from LDP", resp.status, resp.body)
      else
        resp.body
      end
    end

    # turns turtle serialization into Array of RDF::Statements, removing fedora-specific triples
    #  (leaving LDP and OA triples)
    # @param [String] ttl a String containing RDF serialized as turtle
    # @return [Array<RDF::Statements>] the RDF statements represented in the ttl
    def statements_from_ttl_minus_fedora ttl
      # RDF::Turtle::Reader.new(ttl).statements.to_a
      g = RDF::Graph.new.from_ttl(ttl) if ttl
      OA::Graph.remove_fedora_triples(g).statements if g
    end

    def conn
      @c ||= Faraday.new @base_uri
      @c.headers['Prefer'] = 'return=respresentation; omit="http://fedora.info/definitions/v4/repository#ServerManaged"'
      @c
    end

  end

end
