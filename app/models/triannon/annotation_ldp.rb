module Triannon
  # an LDP aware model of an Annotation -- basically, a shim between the OA notion of an annotation 
  #  and the LDP storage.
  class AnnotationLdp

    # RDF::Graph object with all triples, including back end (e.g. LDP, Fedora)
    def graph
      @g ||= RDF::Graph.new
    end

    # RDF::Graph without any back end (e.g. LDP, Fedora) triples
    def stripped_graph
      RDF::LDP.remove_ldp_triples (RDF::FCRepo4.remove_fedora_triples(graph))
    end

    def base_uri
      res = graph.query anno_query
      res.first.s
    end

    def body_uris
      q = anno_query
      q << [:s, RDF::OpenAnnotation.hasBody, :body_uri]
      solns = graph.query q
      result = []
      solns.distinct.each { |soln| 
        result << soln.body_uri 
      }
      result
    end

    def target_uris
      q = anno_query
      q << [:s, RDF::OpenAnnotation.hasTarget, :target_uri]
      solns = graph.query q
      result = []
      solns.distinct.each { |soln| 
        result << soln.target_uri 
      }
      result
    end
    
    # add the passed statements to #graph
    # @param [Array<RDF::Statement>] statements an array of RDF statements to be loaded into the graph
    def load_statements_into_graph statements
      graph.insert(statements) if statements && statements.size > 0
    end

private
    def anno_query
      q = RDF::Query.new
      q << [:s, RDF.type, RDF::OpenAnnotation.Annotation]
    end

  end
end