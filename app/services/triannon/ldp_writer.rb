module Triannon

  # writes data/objects to the LDP server; also does deletes
  class LdpWriter

    # use LDP protocol to create the OpenAnnotation.Annotation in an RDF store
    # @param [Triannon::Annotation] anno a Triannon::Annotation object, from
    #   which we use the graph
    def self.create_anno(anno)
      if anno && anno.graph
        # TODO:  special case if the Annotation object already has an id --
        #  see https://github.com/sul-dlss/triannon/issues/84
        ldp_writer = Triannon::LdpWriter.new anno
        id = ldp_writer.create_base

        bodies_solns = anno.graph.query([nil, RDF::Vocab::OA.hasBody, nil])
        if bodies_solns.size > 0
          ldp_writer.create_body_container
          ldp_writer.create_body_resources
        end

        targets_solns = anno.graph.query([nil, RDF::Vocab::OA.hasTarget, nil])
        # NOTE:  Annotation is invalid if there are no target statements
        if targets_solns.size > 0
          ldp_writer.create_target_container
          ldp_writer.create_target_resources
        end

        id
      end
    end

    # deletes the indicated container and all its child containers from the LDP
    #   store
    # @param [String] id the unique id for the LDP container for an annotation.
    #   May be a compound id, such as  uuid1/t/uuid2, in which case the LDP
    #   container object uuid2 and its children are deleted from the LDP
    #   store, but LDP containers  uuid1/t  and uuid1  are not deleted from
    #   the LDP store.
    def self.delete_container id
      if id && id.size > 0
        ldpw = Triannon::LdpWriter.new nil
        ldpw.delete_containers id
      end
    end

    class << self
      alias_method :delete_anno, :delete_container
    end

    # @param [Triannon::Annotation] anno a Triannon::Annotation object
    # @param [String] id the unique id for the LDP container for the passed
    #   annotation; defaults to nil
    def initialize(anno, id=nil)
      @anno = anno
      @id = id
      @base_uri = "#{Triannon.config[:ldp]['url']}/#{Triannon.config[:ldp]['uber_container']}"
    end

    # creates a stored LDP container for this object's Annotation, without its
    #   targets or bodies (as those are put in descendant containers)
    #   SIDE EFFECT:  assigns the uuid of the container created to @id
    # @return [String] the unique id for the LDP container created for this
    #   annotation
    def create_base
      if @anno.graph.query([nil, RDF::Triannon.externalReference, nil]).count > 0
        raise Triannon::ExternalReferenceError, "Incoming annotations may not have http://triannon.stanford.edu/ns/externalReference as a predicate."
      end

      if @anno.graph.id_as_url && @anno.graph.id_as_url.size > 0
        raise Triannon::ExternalReferenceError, "Incoming new annotations may not have an existing id (yet)."
      end

      # TODO:  special case if the Annotation object already has an id --
      #  see https://github.com/sul-dlss/triannon/issues/84

      # we need to work with a copy of the graph so we don't change @anno.graph
      g = RDF::Graph.new
      @anno.graph.each { |s|
        g << s
      }
      g = OA::Graph.new(g)
      g.remove_non_base_statements
      g.make_null_relative_uri_out_of_blank_node

      @id = create_resource g.to_ttl
    end

    # creates the LDP container for any and all bodies for this annotation
    def create_body_container
      create_direct_container RDF::Vocab::OA.hasBody
    end

    # creates the LDP container for any and all targets for this annotation
    def create_target_container
      create_direct_container RDF::Vocab::OA.hasTarget
    end

    # create the body resources inside the (already created) body container
    def create_body_resources
      create_resources_in_container RDF::Vocab::OA.hasBody
    end

    # create the target resources inside the (already created) target container
    def create_target_resources
      create_resources_in_container RDF::Vocab::OA.hasTarget
    end

    # @param [Array<String>] ldp_container_uris an Array of ids for LDP
    #   containers.  (can also be a String)  e.g. [@base_uri/(uuid1)/t/(uuid2),
    #   @base_uri/(uuid1)/t/(uuid3)] or [@base_uri/(uuid)] or (uuid)
    # @return true if a resource was deleted;  false otherwise
    def delete_containers ldp_container_uris
      return false if !ldp_container_uris || ldp_container_uris.empty?
      if ldp_container_uris.kind_of? String
        ldp_container_uris = [ldp_container_uris]
      end
      something_deleted = false
      ldp_container_uris.each { |uri|
        ldp_id = uri.to_s.split(@base_uri + '/').last
        resp = conn.delete { |req| req.url ldp_id }
        if resp.status != 204
          raise Triannon::LDPStorageError.new("Unable to delete LDP container #{ldp_id}", resp.status, resp.body)
        end
        something_deleted = true
      }
      something_deleted
    end

  protected

    # POSTS a ttl representation of a graph to an existing LDP container in the
    #   LDP store
    # @param [String] ttl a turtle representation of RDF data to be put in the
    #   LDP container
    # @param [String] parent_path the path portion of the url for the LDP parent
    #   container for this resource if no path is supplied, then the resource
    #   will be created as a child of the root annotation; expected paths would
    #   also be (anno_id)/t  for a target resource (inside the target container
    #   of anno_id) or (anno_id)/b for a body resource (inside the body
    #   container of anno_id)
    # @return [String] uuid representing the unique id of the newly created LDP
    #   container
    def create_resource ttl, parent_path = nil
      return if !ttl || ttl.empty?
      resp = conn.post do |req|
        req.url parent_path if parent_path
        req.headers['Content-Type'] = 'application/x-turtle'
        req.body = ttl
      end
      if resp.status != 200 && resp.status != 201
        raise Triannon::LDPStorageError.new("Unable to create LDP resource in container #{parent_path}; RDF sent: #{ttl}", resp.status, resp.body)
      end
      new_url = resp.headers['Location'] ? resp.headers['Location'] : resp.headers['location']
      new_url.split('/').last if new_url
    end

    # Creates an empty LDP DirectContainer in LDP Storage that is a member of
    #   the base container at @id and has the memberRelation per the
    #   oa_vocab_term. The id of the created containter will be (base container
    #   id)/b  if hasBody or  (base container id)/t  if hasTarget
    # @param [RDF::Vocabulary::Term] oa_vocab_term RDF::Vocab::OA.hasTarget or
    #   RDF::Vocab::OA.hasBody
    def create_direct_container oa_vocab_term
      null_rel_uri = RDF::URI.new
      g = RDF::Graph.new
      g << [null_rel_uri, RDF.type, RDF::Vocab::LDP.DirectContainer]
      g << [null_rel_uri, RDF::Vocab::LDP.hasMemberRelation, oa_vocab_term]
      g << [null_rel_uri, RDF::Vocab::LDP.membershipResource, RDF::URI.new("#{@base_uri}/#{@id}")]

      resp = conn.post do |req|
        req.url "#{@id}"
        req.headers['Content-Type'] = 'application/x-turtle'
        # OA vocab relationships all of form "hasXXX" so this becomes 't' or 'b'
        req.headers['Slug'] = oa_vocab_term.fragment.slice(3).downcase
        req.body = g.to_ttl
      end
      if resp.status != 201
        raise Triannon::LDPStorageError.new("Unable to create #{oa_vocab_term.fragment.sub('has', '')} LDP container for anno; RDF sent: #{g.to_ttl}", resp.status, resp.body)
      end
      resp
    end

    # create the target/body resources inside the (already created) target/body
    #   container
    # @param [RDF::URI] predicate either RDF::Vocab::OA.hasTarget or
    #   RDF::Vocab::OA.hasBody
    def create_resources_in_container(predicate)
      predicate_solns = @anno.graph.query([nil, predicate, nil])
      resource_ids = []
      predicate_solns.each { |predicate_stmt |
        graph_for_resource = RDF::Graph.new
        predicate_obj = predicate_stmt.object
        if predicate_obj.is_a?(RDF::Node)
          # we need to use the null relative URI representation of blank nodes
          # to write to LDP
          predicate_subject = RDF::URI.new
        else
          # it's already a URI, but we need to use the null relative URI
          # representation so we can write out as a Triannon:externalRef
          # property with the URL, and any addl props too.
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
        orig_hash_uri_objs = [] # the orig URI objects from [targetObject, OA.hasSource/.default/.item, (uri)] statements
        hash_uri_counter = 1
        OA::Graph.subject_statements(predicate_obj, @anno.graph).each { |s|
          if s.subject == predicate_obj
            # deal with any external URI references which may occur in:
            #   OA.hasSource (from SpecificResource), OA.default or
            #   OA.item (from Choice, Composite, List)
            if s.object.is_a?(RDF::URI) && s.object.to_s
              # do we need to represent the URL as an externalReference
              #   with hash URI?
              if s.predicate == RDF::Vocab::OA.hasSource
                hash_uri_str = "#source"
              elsif s.predicate == RDF::Vocab::OA.default
                hash_uri_str = "#default"
              elsif s.predicate == RDF::Vocab::OA.item
                hash_uri_str = "#item#{hash_uri_counter}"
                hash_uri_counter = hash_uri_counter + 1
              else
                # we don't need to represent the object URI as an external ref
                hash_uri_str = nil
                graph_for_resource << RDF::Statement({:subject => predicate_subject,
                                                      :predicate => s.predicate,
                                                      :object => s.object})
              end

              if hash_uri_str
                # represent the object URL as an external ref
                new_hash_uri_obj = RDF::URI.new(hash_uri_str)
                orig_hash_uri_obj = s.object
                orig_hash_uri_objs << orig_hash_uri_obj
                # add [targetObj, OA.hasSource/.default/.item, (hash URI)]
                graph_for_resource << RDF::Statement({:subject => predicate_subject,
                                                      :predicate => s.predicate,
                                                      :object => new_hash_uri_obj})

                # add externalReference triple to graph
                graph_for_resource << RDF::Statement({:subject => new_hash_uri_obj,
                                                      :predicate => RDF::Triannon.externalReference,
                                                      :object => RDF::URI.new(orig_hash_uri_obj.to_s)})
                # and all of the orig URL's addl props
                OA::Graph.subject_statements(orig_hash_uri_obj, @anno.graph).each { |ss|
                  if ss.subject == orig_hash_uri_obj
                    graph_for_resource << RDF::Statement({:subject => new_hash_uri_obj,
                                                          :predicate => ss.predicate,
                                                          :object => ss.object})
                  else
                    graph_for_resource << ss
                  end
                }
              end
              # NOTE: already dealt with case where there is no hash uri above
            else
              # s.object is not a URI, and subject = predicate_subject -- it may
              #   be a blank node
              graph_for_resource << RDF::Statement({:subject => predicate_subject,
                                                    :predicate => s.predicate,
                                                    :object => s.object})
            end
          else
            # s.subject != predicate_obj
            graph_for_resource << s
          end
        }
        # make sure the graph we will write contains no extraneous statements
        #   about URIs now represented as hash URIs
        orig_hash_uri_objs.each { |uri_node|
          OA::Graph.subject_statements(uri_node, graph_for_resource).each { |s|
            graph_for_resource.delete(s)
          }
        }
        if (predicate == RDF::Vocab::OA.hasTarget)
          resource_ids << create_resource(graph_for_resource.to_ttl, "#{@id}/t")
        else
          resource_ids << create_resource(graph_for_resource.to_ttl, "#{@id}/b")
        end
      }
      resource_ids
    end

    def conn
      @c ||= Faraday.new @base_uri
      @c.headers['Prefer'] = 'return=respresentation; omit="http://fedora.info/definitions/v4/repository#ServerManaged"'
      @c
    end

  end
end
