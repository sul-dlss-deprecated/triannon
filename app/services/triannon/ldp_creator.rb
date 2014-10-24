
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
      result = Triannon::LdpCreator.new anno
      result.create_base

      bodies_solns = anno_graph.query([nil, RDF::OpenAnnotation.hasBody, nil])
      if bodies_solns.size > 0
        result.create_body_container
        result.create_body_resources
      end

      targets_solns = graph.query([nil, RDF::OpenAnnotation.hasTarget, nil])
      # NOTE:  Annotation is invalid if there are no target statements
      result.create_target_container if targets_solns.size > 0
      targets_solns.each { |has_target_stmt|
        create_target_resource subject_statements(has_target_stmt.object, graph)
      }

      result.id
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
      # TODO:  we should error if the Annotation object already has an id

      g = RDF::Graph.new
      @anno.graph.each { |s|
        g << s
      }

      # remove the hasBody statements and any other statements associated with them
      bodies_stmts = g.query([nil, RDF::OpenAnnotation.hasBody, nil])
      bodies_stmts.each { |has_body_stmt |
        g.delete has_body_stmt
        body_obj = has_body_stmt.object
        Triannon::LdpCreator.subject_statements(body_obj, g).each { |s|
          g.delete s
        }
      }

      # remove the hasTarget statements and any other statements associated with them
      targets_stmts = g.query([nil, RDF::OpenAnnotation.hasTarget, nil])
      targets_stmts.each { |has_target_stmt |
        g.delete has_target_stmt
        target_obj = has_target_stmt.object
        Triannon::LdpCreator.subject_statements(target_obj, g).each { |s|
          g.delete s
        }
      }

      # transform an outer blank node into a null relative URI
      anno_stmts = g.query([nil, RDF.type, RDF::OpenAnnotation.Annotation])
      anno_rdf_obj = anno_stmts.first.subject
      if anno_rdf_obj.is_a?(RDF::Node)
        # we need to use the null relative URI representation of blank nodes to write to LDP
        anno_subject = RDF::URI.new
      else # it's already a URI
        anno_subject = anno_rdf_obj
      end
      Triannon::LdpCreator.subject_statements(anno_rdf_obj, g).each { |s|
        if s.subject == anno_rdf_obj && anno_subject != anno_rdf_obj
          g << RDF::Statement({:subject => anno_subject,
                               :predicate => s.predicate,
                               :object => s.object})
          g.delete s
        end
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

    # create the body resources inside the (already created) body container
    def create_body_resources
      bodies_solns = @anno.graph.query([nil, RDF::OpenAnnotation.hasBody, nil])
      body_ids = []
      bodies_solns.each { |has_body_stmt |
        graph_for_resource = RDF::Graph.new
        body_obj = has_body_stmt.object
        if body_obj.is_a?(RDF::Node)
          # we need to use the null relative URI representation of blank nodes to write to LDP
          body_subject = RDF::URI.new
        else 
          # it's already a URI, but we need to use the null relative URI representation so we can
          # write out as a Triannon:externalRef property with the URL, and any addl props too.
          if body_obj.to_str
            body_subject = RDF::URI.new
            graph_for_resource << RDF::Statement({:subject => body_subject,
                                                  :predicate => RDF::Triannon.externalReference,
                                                  :object => RDF::URI.new(body_obj.to_str)})
            addl_stmts = @anno.graph.query([body_obj, nil, nil])
            addl_stmts.each { |s|  
              graph_for_resource << RDF::Statement({:subject => body_subject,
                                                    :predicate => s.predicate,
                                                    :object => s.object})
            }
          else # it's already a null relative URI
            body_subject = body_obj
          end
        end
        # add statements with body_obj as the subject
        Triannon::LdpCreator.subject_statements(body_obj, @anno.graph).each { |s|
          if s.subject == body_obj
            graph_for_resource << RDF::Statement({:subject => body_subject,
                                                  :predicate => s.predicate,
                                                  :object => s.object})
          else
            graph_for_resource << s
          end
        }
        body_ids << create_resource(graph_for_resource.to_ttl, "#{@id}/b")
      }
      body_ids
    end

    # create the target resources inside the (already created) target container
    def create_target_resources
      target_solns = @anno.graph.query([nil, RDF::OpenAnnotation.hasTarget, nil])
      target_ids = []
      target_solns.each { |has_target_stmt |
        graph_for_resource = RDF::Graph.new
        target_obj = has_target_stmt.object
        if target_obj.is_a?(RDF::Node)
          # we need to use the null relative URI representation of blank nodes to write to LDP
          target_subject = RDF::URI.new
        else 
          # it's already a URI, but we need to use the null relative URI representation so we can
          # write out as a Triannon:externalRef property with the URL, and any addl props too.
          if target_obj.to_str
            target_subject = RDF::URI.new
            graph_for_resource << RDF::Statement({:subject => target_subject,
                                                  :predicate => RDF::Triannon.externalReference,
                                                  :object => RDF::Literal.new(target_obj.to_str)})
            addl_stmts = @anno.graph.query([target_obj, nil, nil])
            addl_stmts.each { |s|  
              graph_for_resource << RDF::Statement({:subject => target_subject,
                                                    :predicate => s.predicate,
                                                    :object => s.object})
            }
          else # it's already a null relative URI
            target_subject = target_obj
          end
        end
        # add statements with target_obj as the subject
        Triannon::LdpCreator.subject_statements(target_obj, @anno.graph).each { |s|
          if s.subject == target_obj
            graph_for_resource << RDF::Statement({:subject => target_subject,
                                                  :predicate => s.predicate,
                                                  :object => s.object})
          else
            graph_for_resource << s
          end
        }
        target_ids << create_resource(graph_for_resource.to_ttl, "#{@id}/t")
      }
      target_ids
    end


    # TODO might have to send as blank node since triples getting mixed with fedora internal triples
    #   or create sub-resource /rest/anno/34/b/1/x
    # <> [
    #
    # ]
    # @deprecated use create_body_resources
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

    # @deprecated use create_target_resources
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
