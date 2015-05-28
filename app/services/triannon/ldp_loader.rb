
module Triannon

  # Loads an existing Annotation from the LDP server
  class LdpLoader

    # @param [String] id the unique id of the annotation.  Can include base_uri prefix or omit it.
    # @param [String] root_container the LDP parent container for the annotation
    def self.load(id, root_container)
      l = Triannon::LdpLoader.new(id, root_container)
      l.load_anno_container
      l.load_bodies
      l.load_targets

      oa_graph = Triannon::LdpToOaMapper.ldp_to_oa(l.ldp_annotation, root_container)
      oa_graph
    end

    attr_accessor :ldp_annotation

    # @param [String] id the unique id of the annotation.  Can include base_uri prefix or omit it.
    # @param [String] root_container the LDP parent container for the annotation
    def initialize(id = nil, root_container)
      @id = id
      @root_container = root_container
      if @root_container.blank?
        fail Triannon::LDPContainerError, "Annotations must be in a root container."
      end
      base_url = Triannon.config[:ldp]['url']
      base_url.chop! if base_url.end_with?('/')
      container_path = Triannon.config[:ldp]['uber_container']
      if container_path
        container_path.strip!
        container_path = container_path[1..-1] if container_path.start_with?('/')
        container_path.chop! if container_path.end_with?('/')
      end
      @base_uri = "#{base_url}/#{container_path}"
      @ldp_annotation = Triannon::AnnotationLdp.new
    end

    # load annotation container object into @ldp_annotation's (our Triannon::AnnotationLdp object) graph
    def load_anno_container
      load_object_into_annotation_graph("#{@root_container}/#{@id}")
    end

    # load body objects into @ldp_annotation's (our Triannon::AnnotationLdp object) graph
    def load_bodies
      @ldp_annotation.body_uris.each { |body_uri|
        body_obj_path = body_uri.to_s.split("#{@base_uri}/#{@root_container}/").last
        load_object_into_annotation_graph(body_obj_path)
      }
    end

    # load target objects into @ldp_annotation's (our Triannon::AnnotationLdp object) graph
    def load_targets
      @ldp_annotation.target_uris.each { |target_uri|
        target_obj_path = target_uri.to_s.split("#{@base_uri}/#{@root_container}/").last
        load_object_into_annotation_graph(target_obj_path)
      }
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
        fail Triannon::LDPStorageError.new("error getting #{sub_path} from LDP", resp.status, resp.body)
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
