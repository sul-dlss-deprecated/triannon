
module Triannon

  # creates a new Annotation in the LDP server
  class LdpCreator

    # use LDP protocol to create the OpenAnnotation.Annotation in an RDF store
    # @param [Triannon::Annotation] anno a Triannon::Annotation object
    # @deprecated - use create_from_graph
    def self.create(anno)
      res = Triannon::LdpCreator.new anno
      res.create_base
      # TODO:  create body containers with bodies for EACH body
      res.create_body_container
      res.create_body
      # TODO:  create target containers with bodies for EACH target
      res.create_target_container
      res.create_target
      res.id                                     # TODO just return the pid?
    end

    # use LDP protocol to create the OpenAnnotation.Annotation in an RDF store
    # @param [RDF::Graph] anno_graph an OpenAnnotation.Annotation as an RDF::Graph object
    def self.create_from_graph(anno_graph)
      
      # TODO:  we should not get here if the Annotation object already has an id
      
      res = Triannon::LdpCreator.new anno
      res.create_base
      
      bodies_solns = graph.query([nil, RDF::OpenAnnotation.hasBody, nil])
      if bodies_solns.size > 0
        res.create_body_container
        create_body_resources bodies_graph
      end
        
      targets_solns = graph.query([nil, RDF::OpenAnnotation.hasTarget, nil])
      # NOTE:  Annotation is invalid if there are no target statements
      res.create_target_container if targets_solns.size > 0
      targets_solns.each { |has_target_stmt|
        create_target_resource subject_statements(has_target_stmt.object, graph)
      }
      
      res.id
    end

    # target container stuff:  if there are any blank nodes, the graph to be WRITTEN to 
    # LDP needs to represent them as relative URI resources (no id) with approp descendants
    #   if there are references to external resources (e.g.  a url not in our fedora4 repo), then 
    #   they need to become externalReferences  in fcrepo4
    # Need targets(s) represented in a way that they can be added to the newly created body container
    # 
    # body container stuff:    if there are any blank nodes, the graph to be WRITTEN to 
    # LDP needs to represent them as relative URI resources (no id) with approp descendants
    #   if there are references to external resources (e.g.  a url not in our fedora4 repo), then 
    #   they need to become externalReferences  in fcrepo4
    # Need body(s) represented in a way that they can be added to the newly created body container

    # TODO:  transform the graph as nec. for writing to LDP Container
    #  (i.e.  blank nodes become relative URIs and external references are transformed, and ...)
    # 
    # Returns a single graph object containing subgraphs of each body object.  In the result, 
    # blank nodes represented as an RDF::Node object in the original graph are transformed 
    # into an empty RDF::URI object in the resulting graph as these are relative uris that will
    # be given a specific value when written to the LDP store.
    # 
    # @param [RDF::Graph] graph a Triannon::Annotation as a graph
    # @return [RDF::Graph] a single graph object containing subgraphs of each body object 
    def self.bodies_graph graph
      result = RDF::Graph.new
      stmts = []
      bodies_solns = graph.query([nil, RDF::OpenAnnotation.hasBody, nil])
      bodies_solns.each { |has_body_stmt | 
        body_obj = has_body_stmt.object
        if body_obj.is_a?(RDF::Node)
          # we need to use the null relative URI representation of blank nodes to write to LDP
          body_subject = RDF::URI.new
        else # it's already a URI
          body_subject = body_obj
        end
        # TODO:  deal with external resource references  (see github issues #43 and #10)
        subject_statements(body_obj, graph).each { |s|
          if s.subject == body_obj
            result << RDF::Statement({:subject => body_subject,
                                      :predicate => s.predicate,
                                      :object => s.object}) 
          else
            result << s
          end
        }
      }
      result
    end
    
    # TODO:  transform the graph as nec. for writing to LDP Container
    #  (i.e.  blank nodes become relative URIs and external references are transformed, and ...)
    # 
    # @param [RDF::Graph] graph a Triannon::Annotation as a graph
    # @return [RDF::Graph] a single graph object containing subgraphs of each target object 
    def self.targets_graph graph
      result = RDF::Graph.new
      stmts = []
      targets_solns = graph.query([nil, RDF::OpenAnnotation.hasTarget, nil])
      targets_solns.each { |has_target_stmt | 
        target_obj = has_target_stmt.object
        subject_statements(target_obj, graph).each { |s| 
          result << s 
        }
      }
      result
    end
    
    # given an RDF::Resource (an RDF::Node or RDF::URI), look for all the statements with that object 
    #  as the subject, and recurse through the graph to find all descendant statements pertaining to the subject
    # @param subject the RDF object to be used as the subject in the graph query.  Should be an RDF::Node or RDF::URI
    # @param [RDF::Graph] graph
    # @return [Array[RDF::Statement]] all the triples with the given subject
    def self.subject_statements(subject, graph)
      result = []
      graph.query([subject, nil, nil]).each { |stmt|
        result << stmt
        subject_statements(stmt.object, graph).each { |s| result << s }
      }
      result.uniq
    end 

    attr_accessor :id

    # @param [Triannon::Annotation] anno a Triannon::Annotation object
    def initialize(anno)
      @anno = anno
      @base_uri = Triannon.config[:ldp_url]
    end
    
    # POSTS a ttl representation of the LDP Annotation container to the LDP store
    def create_base
      # TODO:  given that we already have a graph ...
      # remove the hasBody and hasTarget statements, and any blank nodes associated with them 
      #  (see bodies_graph and targets_graph)
      null_rel_uri = RDF::URI.new
      g = RDF::Graph.new
      g << [null_rel_uri, RDF.type, RDF::OpenAnnotation.Annotation]
      @anno.motivated_by.each { |url|
        g << [null_rel_uri, RDF::OpenAnnotation.motivatedBy, RDF::URI.new(url)]
      }
      @id = create_resource g.to_ttl
    end

    # creates the LDP container for any and all bodies for this annotation
    def create_body_container
      create_direct_container RDF::OpenAnnotation.hasBody
    end

    # creates the LDP container for any and all targets for this annotation
    def create_target_container
      create_direct_container RDF::OpenAnnotation.hasTarget
    end
    
    # create the body resources inside the body container
    # @param [RDF::Graph] graph a single graph object containing subgraphs of each body object 
    def create_body_resources graph
      @body_id = create_resource(graph.to_ttl, "#{@id}/b")
      # TODO:  deal with external resource references  (see github issues #43 and #10)
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
        req.headers['Content-Type'] = 'application/x-turtle'
        req.body = body
      end
      new_url = response.headers['Location'] ? response.headers['Location'] : response.headers['location']
      new_url.split('/').last if new_url
    end
    
    # Creates an empty LDP DirectContainer in LDP Storage that is a member of the base container and has the memberRelation per the oa_vocab_term
    # The id of the created containter will be (base container id)b  if hasBody or  (base container id)/t  if hasTarget 
    # @param [RDF::Vocabulary::Term] oa_vocab_term RDF::OpenAnnotation.hasTarget or RDF::OpenAnnotation.hasBody
    def create_direct_container oa_vocab_term
      null_rel_uri = RDF::URI.new
      g = RDF::Graph.new
      g << [null_rel_uri, RDF.type, RDF::LDP.DirectContainer]
      g << [null_rel_uri, RDF::LDP.hasMemberRelation, oa_vocab_term]
      g << [null_rel_uri, RDF::LDP.membershipResource, RDF::URI.new("#{@base_uri}/#{id}")]

      response = conn.post do |req|
        req.url "#{id}"
        req.headers['Content-Type'] = 'application/x-turtle'
        # OA vocab relationships all of form "hasXXX"
        req.headers['Slug'] = oa_vocab_term.fragment.slice(3).downcase
        req.body = g.to_ttl
      end
    end

  end
end
