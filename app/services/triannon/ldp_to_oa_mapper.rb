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
      @ldp = ldp_anno
      @oa_graph = RDF::Graph.new
    end

    def extract_base
      @ldp.stripped_graph.each_statement do |stmnt|
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
      @ldp.body_uris.each { |body_uri|  
        res = @ldp.stripped_graph.query [body_uri, RDF.type, RDF::Content.ContentAsText]
        if res.count > 0 # TODO raise if this fails?
          body_node = RDF::Node.new
          @oa_graph << [@root_uri, RDF::OpenAnnotation.hasBody, body_node]
          @oa_graph << [body_node, RDF.type, RDF::Content.ContentAsText]
          @oa_graph << [body_node, RDF.type, RDF::DCMIType.Text]
          res_chars = @ldp.stripped_graph.query [body_uri, RDF::Content.chars, nil]
          if res_chars.count > 0
            @oa_graph << [body_node, RDF::Content.chars, res_chars.first.object]
          end
        end
      }
    end

    def extract_target
      @ldp.target_uris.each { |target_uri|  
        res = @ldp.stripped_graph.query [target_uri, RDF::Triannon.externalReference, nil]
        if res.count > 0
          ext_uri = res.first.object
          @oa_graph << [@root_uri, RDF::OpenAnnotation.hasTarget, ext_uri]
        end
      }
    end

  end

end
