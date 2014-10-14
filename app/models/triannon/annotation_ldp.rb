module Triannon
  class AnnotationLdp

    def graph
      @g ||= RDF::Graph.new
    end

    # returns graph without any ldp triples
    def graph_no_ldp
      @no_ldp_graph ||= begin
        no_ldp_graph = RDF::Graph.new
        ldp_props = RDF::LDP.properties.map {|p| p.to_s}
        graph.each { |stmt|  
          no_ldp_graph << stmt unless ldp_props.include?(stmt.predicate.to_s) || 
                                      (stmt.predicate == RDF.type && ldp_props.include?(stmt.object.to_s))
        }
        no_ldp_graph
      end
    end
    
    # returns graph without any fedora triples
    def remove_fedora_triples graph
      fedora_ns = "http://fedora.info/definitions"
      modeshape_ns = "http://www.jcp.org/jcr"
      no_fedora_graph = RDF::Graph.new
      ldp_props = RDF::LDP.properties.map {|p| p.to_s}
      graph.each { |stmt|  
        no_fedora_graph << stmt unless stmt.predicate.to_s.match(fedora_ns) ||
                                    stmt.predicate.to_s.match(modeshape_ns) || 
                                    stmt.subject.to_s.match(fedora_ns) ||
                                    stmt.object.to_s.match(fedora_ns) ||
                                    (stmt.predicate == RDF.type && stmt.object.to_s.match(modeshape_ns))
      }
      no_fedora_graph
    end

    def base_uri
      res = graph.query anno_query
      res.first.s
    end

    def body_uri
      q = anno_query
      q << [:s, RDF::OpenAnnotation.hasBody, :uri]
      res = graph.query q
      res.first.uri
    end

    def target_uri
      q = anno_query
      q << [:s, RDF::OpenAnnotation.hasTarget, :uri]
      res = graph.query q
      res.first.uri
    end

    def load_data_into_graph ttl
      graph.from_ttl ttl
    end

private
    def anno_query
      q = RDF::Query.new
      q << [:s, RDF.type, RDF::OpenAnnotation.Annotation]
    end

  end
end