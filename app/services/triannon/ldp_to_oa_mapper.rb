module Triannon
  class LdpToOaMapper

    # maps an AnnotationLdp to an OA RDF::Graph
    def self.ldp_to_oa ldp_anno
      mapper = Triannon::LdpToOaMapper.new ldp_anno
      mapper.extract_base
      mapper.extract_body
      mapper.extract_target
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

    def extract_body
      @ldp_anno.body_uris.each { |body_uri|
        if !map_external_ref(body_uri, RDF::OpenAnnotation.hasBody)
          solns = @ldp_anno_graph.query [body_uri, RDF.type, RDF::Content.ContentAsText]
          if solns.count > 0
            body_node = RDF::Node.new
            @oa_graph << [@root_uri, RDF::OpenAnnotation.hasBody, body_node]
            @oa_graph << [body_node, RDF.type, RDF::Content.ContentAsText]
            @oa_graph << [body_node, RDF.type, RDF::DCMIType.Text]
            chars_solns = @ldp_anno_graph.query [body_uri, RDF::Content.chars, nil]
            if chars_solns.count > 0
              @oa_graph << [body_node, RDF::Content.chars, chars_solns.first.object]
            end
          end
        end
      }
    end

    def extract_target
      @ldp_anno.target_uris.each { |target_uri| 
        map_external_ref(target_uri, RDF::OpenAnnotation.hasTarget)
      }
    end
    
    # if uri_obj is the subject of a Triannon.externalReference then add appropriate
    #  statements to @oa_graph
    # @param [RDF::URI] uri_obj the object that may have RDF::Triannon.externalReference
    # @param [RDF::URI] predicate the predicate for [@root_uri, predicate, (ext_url)] statement
    # to be added to @oa_graph, e.g. RDF::OpenAnnotation.hasTarget
    # @returns [Boolean] true if it adds statements to @oa_graph, false otherwise
    def map_external_ref uri_obj, predicate
      solns = @ldp_anno_graph.query [uri_obj, RDF::Triannon.externalReference, nil]
      if solns.count > 0
        external_uri = solns.first.object
        @oa_graph << [@root_uri, predicate, external_uri]
        true
      else
        false
      end
    end
    
  end

end
