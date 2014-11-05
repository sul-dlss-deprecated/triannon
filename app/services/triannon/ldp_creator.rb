
module Triannon

  # creates a new Annotation in the LDP server
  class LdpCreator

    # use LDP protocol to create the OpenAnnotation.Annotation in an RDF store
    # @param [Triannon::Annotation] anno a Triannon::Annotation object, from which we use the graph
    def self.create(anno)
      if anno && anno.graph
        # TODO:  we should not get here if the Annotation object already has an id
        result = Triannon::LdpCreator.new anno
        result.create_base

        bodies_solns = anno.graph.query([nil, RDF::OpenAnnotation.hasBody, nil])
        if bodies_solns.size > 0
          result.create_body_container
          result.create_body_resources
        end

        targets_solns = anno.graph.query([nil, RDF::OpenAnnotation.hasTarget, nil])
        # NOTE:  Annotation is invalid if there are no target statements
        if targets_solns.size > 0
          result.create_target_container
          result.create_target_resources
        end

        result.id
      end
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
      create_resources_in_container RDF::OpenAnnotation.hasBody
    end
    
    # create the target resources inside the (already created) target container
    def create_target_resources
      create_resources_in_container(RDF::OpenAnnotation.hasTarget)
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

    # create the target/body resources inside the (already created) target/body container
    # @param [RDF::URI] predicate either RDF::OpenAnnotation.hasTarget or RDF::OpenAnnotation.hasBody
    def create_resources_in_container(predicate)
      predicate_solns = @anno.graph.query([nil, predicate, nil])
      resource_ids = []
      predicate_solns.each { |predicate_stmt |
        graph_for_resource = RDF::Graph.new
        predicate_obj = predicate_stmt.object
        if predicate_obj.is_a?(RDF::Node)
          # we need to use the null relative URI representation of blank nodes to write to LDP
          predicate_subject = RDF::URI.new
        else 
          # it's already a URI, but we need to use the null relative URI representation so we can
          # write out as a Triannon:externalRef property with the URL, and any addl props too.
          if predicate_obj.to_str
            predicate_subject = RDF::URI.new
            graph_for_resource << RDF::Statement({:subject => predicate_subject,
                                                  :predicate => RDF::Triannon.externalReference,
                                                  :object => RDF::URI.new(predicate_obj.to_str)})
            addl_stmts = @anno.graph.query([predicate_obj, nil, nil])
            addl_stmts.each { |s|  
              graph_for_resource << RDF::Statement({:subject => predicate_subject,
                                                    :predicate => s.predicate,
                                                    :object => s.object})
            }
          else # it's already a null relative URI
            predicate_subject = predicate_obj
          end
        end
        # add statements with predicate_obj as the subject
        orig_source_objects = [] # the object URI nodes  from  targetObject, OA.hasSource, (uri) statements
        Triannon::LdpCreator.subject_statements(predicate_obj, @anno.graph).each { |s|
          if s.subject == predicate_obj
            # deal with external references in hasSource statements (i.e.  targetObject, OA.hasSource, (url) )
            if s.predicate == RDF::OpenAnnotation.hasSource && s.object.is_a?(RDF::URI) && s.object.to_str
              # we need to represent the source URL as an externalReference - use a hash URI
              source_object = RDF::URI.new("#source")
              orig_source_objects << s.object
              graph_for_resource << RDF::Statement({:subject => source_object,
                                                    :predicate => RDF::Triannon.externalReference,
                                                    :object => RDF::URI.new(s.object.to_str)})
              # and all of the source URL's addl props
              Triannon::LdpCreator.subject_statements(s.object, @anno.graph).each { |ss|
                if ss.subject == s.object
                  graph_for_resource << RDF::Statement({:subject => source_object,
                                                        :predicate => ss.predicate,
                                                        :object => ss.object})
                else
                  graph_for_resource << ss
                end
              }
              # add the targetObj, OA.hasSource, (hash URI representation) to graph
              graph_for_resource << RDF::Statement({:subject => predicate_subject,
                                                    :predicate => s.predicate,
                                                    :object => source_object})
            else
              graph_for_resource << RDF::Statement({:subject => predicate_subject,
                                                    :predicate => s.predicate,
                                                    :object => s.object})
            end
          else
            graph_for_resource << s
          end
        }
        # make sure the graph we will write contains no extraneous statements about source URI
        #  now represented as hash URI (#source)
        orig_source_objects.each { |rdf_uri_node| 
          Triannon::LdpCreator.subject_statements(rdf_uri_node, graph_for_resource).each { |s|  
            graph_for_resource.delete(s)
          }
        }
        if (predicate == RDF::OpenAnnotation.hasTarget)
          resource_ids << create_resource(graph_for_resource.to_ttl, "#{@id}/t")
        else
          resource_ids << create_resource(graph_for_resource.to_ttl, "#{@id}/b")
        end
      }
      resource_ids
    end
    
  end
end
