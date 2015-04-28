module Triannon
  # an LDP aware model of an Annotation -- basically, a shim between the OA
  #  notion of an annotation and the LDP storage.
  class AnnotationLdp

    # RDF::Graph object with all triples, including back end (e.g. LDP, Fedora)
    def graph
      @g ||= RDF::Graph.new
    end

    # RDF::Graph without any back end (e.g. LDP, Fedora) triples
    def stripped_graph
      OA::Graph.remove_ldp_triples(OA::Graph.remove_fedora_triples(graph))
    end

    def base_uri
      res = graph.query OA::Graph.anno_query
      res.first.s
    end

    # @return [Array<String>] the uris of each LDP body resource
    def body_uris
      q = OA::Graph.anno_query.dup
      q << [:s, RDF::Vocab::OA.hasBody, :body_uri]
      solns = graph.query q
      result = []
      solns.distinct.each { |soln|
        result << soln.body_uri
      }
      result
    end

    # @return [Array<String>] the uris of each LDP target resource
    def target_uris
      q = OA::Graph.anno_query.dup
      q << [:s, RDF::Vocab::OA.hasTarget, :target_uri]
      solns = graph.query q
      result = []
      solns.distinct.each { |soln|
        result << soln.target_uri
      }
      result
    end

    # add the passed statements to #graph
    # @param [Array<RDF::Statement>] statements an array of RDF statements to be
    #   loaded into the graph
    def load_statements_into_graph(statements)
      graph.insert(statements) if statements && statements.size > 0
    end

  end
end
