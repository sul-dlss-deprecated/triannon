module Triannon
  class LdpToOaMapper

    # maps a Triannon::AnnotationLdp to an OA RDF::Graph
    # @param [Triannon::AnnotationLdp] ldp_anno
    # @param [String] root_container the LDP parent container for the annotation
    def self.ldp_to_oa(ldp_anno, root_container)
      mapper = Triannon::LdpToOaMapper.new(ldp_anno, root_container)
      mapper.extract_base
      mapper.extract_bodies
      mapper.extract_targets
      mapper.oa_graph
    end

    attr_accessor :id, :oa_graph

    # @param [Triannon::AnnotationLdp] ldp_anno
    # @param [String] root_container the LDP parent container for the annotation
    def initialize(ldp_anno, root_container)
      @ldp_anno = ldp_anno
      @root_container = root_container
      @ldp_anno_graph = ldp_anno.stripped_graph
      g = RDF::Graph.new
      @oa_graph = OA::Graph.new g
    end

    # load statements from base anno container into @oa_graph
    def extract_base
      root_subject_solns = @ldp_anno_graph.query OA::Graph.anno_query
      #for some reason the query returns nil instead of an empty array?
      if root_subject_solns && root_subject_solns.count == 1
        stored_url = Triannon.config[:ldp]['url'].strip
        stored_url.chop! if stored_url.end_with?('/')
        uber_container = Triannon.config[:ldp]['uber_container'].strip
        if uber_container
          uber_container = uber_container[1..-1] if uber_container.start_with?('/')
          uber_container.chop! if uber_container.end_with?('/')
          stored_url = "#{stored_url}/#{uber_container}/#{@root_container}"
        end
        @id = root_subject_solns[0].s.to_s.split("#{stored_url}/").last
        base_url = Triannon.config[:triannon_base_url].strip
        base_url.chop! if base_url[-1] == '/'
        @root_uri = RDF::URI.new(base_url + "/#{@root_container}/#{@id}")
      end

      @ldp_anno_graph.each_statement do |stmnt|
        if stmnt.predicate == RDF.type && stmnt.object == RDF::Vocab::OA.Annotation
          @oa_graph << [@root_uri, RDF.type, RDF::Vocab::OA.Annotation]
        elsif stmnt.predicate == RDF::Vocab::OA.motivatedBy
          @oa_graph << [@root_uri, stmnt.predicate, stmnt.object]
        elsif stmnt.predicate == RDF::Vocab::OA.annotatedAt
          @oa_graph << [@root_uri, stmnt.predicate, stmnt.object]
        end
      end
    end

    # load statements from anno body containers into @oa_graph
    def extract_bodies
      @ldp_anno.body_uris.each { |body_uri|
        if !map_external_ref(body_uri, RDF::Vocab::OA.hasBody) &&
            !map_content_as_text(body_uri, RDF::Vocab::OA.hasBody) &&
            !map_specific_resource(body_uri, RDF::Vocab::OA.hasBody)
          map_choice(body_uri, RDF::Vocab::OA.hasBody)
        end
      }
    end

    # load statements from anno target containers into @oa_graph
    def extract_targets
      @ldp_anno.target_uris.each { |target_uri|
        if !map_external_ref(target_uri, RDF::Vocab::OA.hasTarget) &&
            !map_specific_resource(target_uri, RDF::Vocab::OA.hasTarget)
          map_choice(target_uri, RDF::Vocab::OA.hasTarget)
        end
      }
    end

    # if uri_obj is the subject of a Triannon.externalReference then add appropriate
    #  statements to @oa_graph and return true
    # @param [RDF::URI] uri_obj the object that may have RDF::Triannon.externalReference
    # @param [RDF::URI] predicate the predicate for [subject_obj, predicate, (ext_url)] statement
    # to be added to @oa_graph, e.g. RDF::Vocab::OA.hasTarget
    # @param [RDF::URI] subject_obj the subject object to get the predicate statement; defaults to @root_uri
    # @return [Boolean] true if it adds statements to @oa_graph, false otherwise
    def map_external_ref uri_obj, predicate, subject_obj = @root_uri
      solns = @ldp_anno_graph.query [uri_obj, RDF::Triannon.externalReference, nil]
      #for some reason the query returns nil instead of an empty array?
      if solns && solns.count > 0
        external_uri = solns.first.object
        @oa_graph << [subject_obj, predicate, external_uri]

        OA::Graph.subject_statements(uri_obj, @ldp_anno_graph).each { |stmt|
          if stmt.subject == uri_obj && stmt.predicate != RDF::Triannon.externalReference
            @oa_graph << [external_uri, stmt.predicate, stmt.object]
          else
            # we should never get here for external references ...
          end
        }
        true
      else
        false
      end
    end

    # if uri_obj has a type of RDF::Vocab::CNT.ContentAsText, then this is a skolemized blank node;
    #  add appropriate statements to @oa_graph to represent the blank node and its contents and return true
    # @param [RDF::URI] uri_obj the object that may type RDF::Vocab::CNT.ContentAsText
    # @param [RDF::URI] predicate the predicate for [subject_obj, predicate, (ext_url)] statement
    # to be added to @oa_graph, e.g. RDF::Vocab::OA.hasTarget
    # @param [RDF::URI] subject_obj the subject object to get the predicate statement; defaults to @root_uri
    # @return [Boolean] true if it adds statements to @oa_graph, false otherwise
    def map_content_as_text uri_obj, predicate, subject_obj = @root_uri
      solns = @ldp_anno_graph.query [uri_obj, RDF.type, RDF::Vocab::CNT.ContentAsText]
      #for some reason the query returns nil instead of an empty array?
      if solns && solns.count > 0
        blank_node = RDF::Node.new
        @oa_graph << [subject_obj, predicate, blank_node]

        OA::Graph.subject_statements(uri_obj, @ldp_anno_graph).each { |stmt|
          if stmt.subject == uri_obj
            @oa_graph << [blank_node, stmt.predicate, stmt.object]
          else
            # it is a descendant statment - take as is
            @oa_graph << stmt
          end
        }
        true
      else
        false
      end
    end

    # if uri_obj has a type of RDF::Vocab::OA.SpecificResource, then this is a skolemized blank node;
    #  add appropriate statements to @oa_graph to represent the blank node and its contents and return true
    # @param [RDF::URI] uri_obj the object that may have type RDF::Vocab::OA.SpecificResource
    # @param [RDF::URI] predicate the predicate for [@root_uri, predicate, (sel_res)] statement
    # to be added to @oa_graph, e.g. RDF::Vocab::OA.hasTarget
    # @return [Boolean] true if it adds statements to @oa_graph, false otherwise
    def map_specific_resource uri_obj, predicate
      solns = @ldp_anno_graph.query [uri_obj, RDF.type, RDF::Vocab::OA.SpecificResource]
      #for some reason the query returns nil instead of an empty array?
      if solns && solns.count > 0
        blank_node = RDF::Node.new
        @oa_graph << [@root_uri, predicate, blank_node]

        source_obj = nil
        selector_obj = nil
        selector_blank_node = nil
        specific_res_stmts = OA::Graph.subject_statements(uri_obj, @ldp_anno_graph)
        specific_res_stmts.each { |stmt|
          if stmt.predicate == RDF::Vocab::OA.hasSource
            # expecting a hash URI
            source_obj = stmt.object
            if source_obj.to_s.match("#{uri_obj}#source")
              source_has_ext_uri = map_external_ref source_obj, RDF::Vocab::OA.hasSource, blank_node
            end
          elsif stmt.predicate == RDF::Vocab::OA.hasSelector
            # this becomes a blank node.  Per http://www.openannotation.org/spec/core/specific.html#Selectors
            # "Typically if all of the information needed to resolve the Selector (or other Specifier)
            #  is present within the graph, such as is the case for the
            # FragmentSelector, TextQuoteSelector, TextPositionSelector and DataPositionSelector classes,
            # then there is no need to have a resolvable resource that provides the same information."
            selector_obj = stmt.object
            selector_blank_node = RDF::Node.new
            @oa_graph << [blank_node, RDF::Vocab::OA.hasSelector, selector_blank_node]
          end
        }

        # We can't know we'll hit hasSource and hasSelector statements in graph first,
        # so we must do another pass through the statements to get that information
        specific_res_stmts.each { |stmt|
          if stmt.subject == uri_obj && stmt.object != source_obj && stmt.object != selector_obj
            @oa_graph << [blank_node, stmt.predicate, stmt.object]
          elsif stmt.subject != source_obj
            if selector_blank_node && stmt.subject == selector_obj
              @oa_graph << [selector_blank_node, stmt.predicate, stmt.object]
            end
          # there shouldn't be any other statements present
          end
        }
        true
      else
        false
      end
    end

    # if uri_obj has a type of RDF::Vocab::OA.Choice, then this is a skolemized blank node;
    #  add appropriate statements to @oa_graph to represent the blank node and its contents and return true
    # @param [RDF::URI] uri_obj the object that may have type RDF::Vocab::OA.Choice
    # @param [RDF::URI] predicate the predicate for [@root_uri, predicate, (choice)] statement
    # to be added to @oa_graph, e.g. RDF::Vocab::OA.hasTarget
    # @return [Boolean] true if it adds statements to @oa_graph, false otherwise
    def map_choice uri_obj, predicate
      solns = @ldp_anno_graph.query [uri_obj, RDF.type, RDF::Vocab::OA.Choice]
      #for some reason the query returns nil instead of an empty array?
      if solns && solns.count > 0
        blank_node = RDF::Node.new
        @oa_graph << [@root_uri, predicate, blank_node]

        default_obj = nil
        item_objs = []
        choice_stmts = OA::Graph.subject_statements(uri_obj, @ldp_anno_graph)
        choice_stmts.each { |stmt|
          if stmt.predicate == RDF::Vocab::OA.default
            default_obj = stmt.object
            # assume it is either ContentAsText or external ref
            if !map_content_as_text(default_obj, RDF::Vocab::OA.default, blank_node)
              map_external_ref(default_obj, RDF::Vocab::OA.default, blank_node)
            end
          elsif stmt.predicate == RDF::Vocab::OA.item
            item_objs << stmt.object
            # assume it is either ContentAsText or external ref
            if !map_content_as_text(stmt.object, RDF::Vocab::OA.item, blank_node)
              map_external_ref(stmt.object, RDF::Vocab::OA.item, blank_node)
            end
          end
        }

        # We can't know we'll hit item and default statements in graph first,
        # so we must do another pass through the statements to get that information
        choice_stmts.each { |stmt|
          if stmt.subject == uri_obj && stmt.object != default_obj && !item_objs.include?(stmt.object)
            @oa_graph << [blank_node, stmt.predicate, stmt.object]
          # there shouldn't be any other unmapped statements present
          end
        }
        true
      else
        false
      end
    end

  end

end
