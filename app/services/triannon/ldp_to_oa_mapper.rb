module Triannon
  class LdpToOaMapper

    # maps an AnnotationLdp to an OA RDF::Graph
    def self.ldp_to_oa ldp_anno
      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      mapper.extract_bodies
      mapper.extract_targets
      mapper.oa_graph
    end

    attr_accessor :id, :oa_graph

    def initialize ldp_anno
      @ldp_anno = ldp_anno
      @ldp_anno_graph = ldp_anno.stripped_graph
      @oa_graph = RDF::Graph.new
    end

    def extract_base
      @ldp_anno_graph.each_statement do |stmnt|
        if stmnt.predicate == RDF.type && stmnt.object == RDF::OpenAnnotation.Annotation
          @id = stmnt.subject.to_s.split('/').last
          @root_uri = RDF::URI.new(Triannon.config[:triannon_base_url] + "/#{@id}")
          @oa_graph << [@root_uri, RDF.type, RDF::OpenAnnotation.Annotation]

        elsif stmnt.predicate == RDF::OpenAnnotation.motivatedBy
          @oa_graph << [@root_uri, stmnt.predicate, stmnt.object]
        end
      end
    end

    def extract_bodies
      @ldp_anno.body_uris.each { |body_uri|
        if !map_external_ref(body_uri, RDF::OpenAnnotation.hasBody) &&
            !map_content_as_text(body_uri, RDF::OpenAnnotation.hasBody) &&
            !map_specific_resource(body_uri, RDF::OpenAnnotation.hasBody)
          map_choice(body_uri, RDF::OpenAnnotation.hasBody)
        end
      }
    end

    def extract_targets
      @ldp_anno.target_uris.each { |target_uri| 
        if !map_external_ref(target_uri, RDF::OpenAnnotation.hasTarget) &&
            !map_specific_resource(target_uri, RDF::OpenAnnotation.hasTarget)
          map_choice(target_uri, RDF::OpenAnnotation.hasTarget)
        end
      }
    end
    
    # if uri_obj is the subject of a Triannon.externalReference then add appropriate
    #  statements to @oa_graph and return true
    # @param [RDF::URI] uri_obj the object that may have RDF::Triannon.externalReference
    # @param [RDF::URI] predicate the predicate for [subject_obj, predicate, (ext_url)] statement
    # to be added to @oa_graph, e.g. RDF::OpenAnnotation.hasTarget
    # @param [RDF::URI] the subject object to get the predicate statement; defaults to @root_uri
    # @returns [Boolean] true if it adds statements to @oa_graph, false otherwise
    def map_external_ref uri_obj, predicate, subject_obj = @root_uri
      solns = @ldp_anno_graph.query [uri_obj, RDF::Triannon.externalReference, nil]
      if solns.count > 0
        external_uri = solns.first.object
        @oa_graph << [subject_obj, predicate, external_uri]
        
        Triannon::LdpCreator.subject_statements(uri_obj, @ldp_anno_graph).each { |stmt|
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
    
    # if uri_obj has a type of RDF::Content.ContentAsText, then this is a skolemized blank node;
    #  add appropriate statements to @oa_graph to represent the blank node and its contents and return true
    # @param [RDF::URI] uri_obj the object that may type RDF::Content.ContentAsText
    # @param [RDF::URI] predicate the predicate for [subject_obj, predicate, (ext_url)] statement
    # to be added to @oa_graph, e.g. RDF::OpenAnnotation.hasTarget
    # @param [RDF::URI] the subject object to get the predicate statement; defaults to @root_uri
    # @returns [Boolean] true if it adds statements to @oa_graph, false otherwise
    def map_content_as_text uri_obj, predicate, subject_obj = @root_uri
      solns = @ldp_anno_graph.query [uri_obj, RDF.type, RDF::Content.ContentAsText]
      if solns.count > 0
        blank_node = RDF::Node.new
        @oa_graph << [subject_obj, predicate, blank_node]
        
        Triannon::LdpCreator.subject_statements(uri_obj, @ldp_anno_graph).each { |stmt|
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
    
    # if uri_obj has a type of RDF::OpenAnnotation.SpecificResource, then this is a skolemized blank node;
    #  add appropriate statements to @oa_graph to represent the blank node and its contents and return true
    # @param [RDF::URI] uri_obj the object that may have type RDF::OpenAnnotation.SpecificResource
    # @param [RDF::URI] predicate the predicate for [@root_uri, predicate, (sel_res)] statement
    # to be added to @oa_graph, e.g. RDF::OpenAnnotation.hasTarget
    # @returns [Boolean] true if it adds statements to @oa_graph, false otherwise
    def map_specific_resource uri_obj, predicate
      solns = @ldp_anno_graph.query [uri_obj, RDF.type, RDF::OpenAnnotation.SpecificResource]
      if solns.count > 0
        blank_node = RDF::Node.new
        @oa_graph << [@root_uri, predicate, blank_node]
        
        source_obj = nil
        selector_obj = nil
        selector_blank_node = nil
        specific_res_stmts = Triannon::LdpCreator.subject_statements(uri_obj, @ldp_anno_graph)
        specific_res_stmts.each { |stmt|
          if stmt.predicate == RDF::OpenAnnotation.hasSource
            # expecting a hash URI
            source_obj = stmt.object
            if source_obj.to_s.match("#{uri_obj.to_s}#source")
              source_has_ext_uri = map_external_ref source_obj, RDF::OpenAnnotation.hasSource, blank_node
            end
          elsif stmt.predicate == RDF::OpenAnnotation.hasSelector
            # this becomes a blank node.  Per http://www.openannotation.org/spec/core/specific.html#Selectors
            # "Typically if all of the information needed to resolve the Selector (or other Specifier)
            #  is present within the graph, such as is the case for the 
            # FragmentSelector, TextQuoteSelector, TextPositionSelector and DataPositionSelector classes, 
            # then there is no need to have a resolvable resource that provides the same information."
            selector_obj = stmt.object
            selector_blank_node = RDF::Node.new
            @oa_graph << [blank_node, RDF::OpenAnnotation.hasSelector, selector_blank_node]
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

    # if uri_obj has a type of RDF::OpenAnnotation.Choice, then this is a skolemized blank node;
    #  add appropriate statements to @oa_graph to represent the blank node and its contents and return true
    # @param [RDF::URI] uri_obj the object that may have type RDF::OpenAnnotation.Choice
    # @param [RDF::URI] predicate the predicate for [@root_uri, predicate, (choice)] statement
    # to be added to @oa_graph, e.g. RDF::OpenAnnotation.hasTarget
    # @returns [Boolean] true if it adds statements to @oa_graph, false otherwise
    def map_choice uri_obj, predicate
      solns = @ldp_anno_graph.query [uri_obj, RDF.type, RDF::OpenAnnotation.Choice]
      if solns.count > 0
        blank_node = RDF::Node.new
        @oa_graph << [@root_uri, predicate, blank_node]
        
        default_obj = nil
        item_obj = nil
        choice_stmts = Triannon::LdpCreator.subject_statements(uri_obj, @ldp_anno_graph)
        choice_stmts.each { |stmt|
          if stmt.predicate == RDF::OpenAnnotation.default
            default_obj = stmt.object
            # assume it is either ContentAsText or external ref
            if !map_content_as_text(default_obj, RDF::OpenAnnotation.default, blank_node)
              map_external_ref default_obj, RDF::OpenAnnotation.default, blank_node
            end
          elsif stmt.predicate == RDF::OpenAnnotation.item
            item_obj = stmt.object
            # assume it is either ContentAsText or external ref
            if !map_content_as_text(item_obj, RDF::OpenAnnotation.item, blank_node)
              map_external_ref item_obj, RDF::OpenAnnotation.item, blank_node
            end
          end
        }
        
        # We can't know we'll hit item and default statements in graph first, 
        # so we must do another pass through the statements to get that information
        choice_stmts.each { |stmt| 
          if stmt.subject == uri_obj && stmt.object != default_obj && stmt.object != item_obj
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
