
module Triannon

  # creates a new Annotation in the LDP server
  class LdpCreator

    def self.create(anno)                       # TODO just pass simple strings/arrays/hashes? :body => [,,], :target => [,,], :motivation => [,,]
      res = Triannon::LdpCreator.new anno
      res.create
      # TODO:  create body containers with bodies for EACH body
      res.create_body_container
      res.create_body
      # TODO:  create target containers with bodies for EACH target
      res.create_target_container
      res.create_target
      res.id                                     # TODO just return the pid?
    end

    attr_accessor :id

    # @param [Triannon::Annotation] anno a Triannon::Annotation object
    def initialize(anno)
      @anno = anno
      @base_uri = Triannon.config[:ldp_url]
    end

    # POSTS a ttl representation of the LDP Annotation container to the LDP store
    #  uses inline hardcoded ttl, and only looks at single motivation
    # @deprecated - use create_base
    def create
      motivation = @anno.motivated_by.first
      ttl  =<<-EOTL
        <> a <http://www.w3.org/ns/oa#Annotation>;
           <http://www.w3.org/ns/oa#motivatedBy> <#{motivation}> .
      EOTL

      @id = create_resource ttl
    end

    def create_body_container
      ttl =<<-TTL
        @prefix ldp: <http://www.w3.org/ns/ldp#> .
        @prefix oa: <http://www.w3.org/ns/oa#> .

        <> a ldp:DirectContainer;
           ldp:hasMemberRelation oa:hasBody;
           ldp:membershipResource <#{@base_uri}/#{id}> .
      TTL

      create_container :body, ttl
    end

    def create_target_container
      ttl =<<-TTL
        @prefix ldp: <http://www.w3.org/ns/ldp#> .
        @prefix oa: <http://www.w3.org/ns/oa#> .

        <> a ldp:DirectContainer;
           ldp:hasMemberRelation oa:hasTarget;
           ldp:membershipResource <#{@base_uri}/#{id}> .
      TTL

      create_container :target, ttl
    end

    # TODO might have to send as blank node since triples getting mixed with fedora internal triples
    #   or create sub-resource /rest/anno/34/b/1/x
    # <> [
    #
    # ]
    def create_body
      body_chars = @anno.has_body.first        # TODO handle more than just one body or different types
      ttl =<<-TTL
        @prefix cnt: <http://www.w3.org/2011/content#> .
        @prefix dctypes: <http://purl.org/dc/dcmitype/> .

        <> a cnt:ContentAsText, dctypes:Text;
           cnt:chars '#{body_chars}' .
      TTL

      @body_id = create_resource ttl, "#{@id}/b"
    end

    def create_target
      target = @anno.has_target.first        # TODO handle more than just one target or different types
      ttl =<<-TTL
        @prefix dc: <http://purl.org/dc/elements/1.1/> .
        @prefix dctypes: <http://purl.org/dc/dcmitype/> .
        @prefix triannon: <http://triannon.stanford.edu/ns/> .

        <> a dctypes:Text;
           dc:format 'text/html';
           triannon:externalReference <#{target}> .
      TTL

      @target_id = create_resource ttl, "#{@id}/t"
    end

    def conn
      @c ||= Faraday.new @base_uri
    end

  protected
    def create_resource body, url = nil
      response = conn.post do |req|
        req.url url if url
        req.headers['Content-Type'] = 'text/turtle'
        req.body = body
      end
      response.headers['Location'].split('/').last
    end

    def create_container type, body
      conn.post do |req|
        req.url "#{id}"
        req.headers['Content-Type'] = 'text/turtle'
        req.headers['Slug'] = type.to_s.chars.first
        req.body = body
      end
    end
    
    # @param [RDF::Graph] graph a Triannon::Annotation as a graph
    # @return [RDF::Graph] all the triples with a body as a subject, as a single graph object
    def get_bodies_graph graph
      
    end
    
    # @param [RDF::Graph] graph a Triannon::Annotation as a graph
    # @return [RDF::Graph] all the triples with a target as a subject, as a single graph object
    def get_targets_graph graph
      result = []
      targets_solns = graph.query([nil, RDF::OpenAnnotation.hasTarget, nil])
      # FIXME:  can get has_target statements from triannon object itself
      targets_solns.each { |has_target_stmt| 
        target_obj = has_target_stmt.object
        result = statements_for_subject (target_obj)
      }
      result
    end
    
    # @param subject the RDF object to be used as the subject in the graph query.  Should be an RDF::Node or RDF::URI
    # @param [RDF::Graph] graph
    # @return [Array[RDF::Statement]] all the triples with the given subject
    def subject_statements(subject, graph)      
      result = []
      if subject.is_a? RDF::Node
        stmts = graph.query([subject, nil, nil])
        stmts.each { |s|
          result << s
          if s.object.is_a? RDF::Node
            subject_statements(s.object, graph).each { |s| result << s }
          end
        }
      end
      result.uniq
    end 
    
  end
end
