module Triannon
  class AnnotationLdp

    # RDF::Graph object with all triples, including back end (e.g. LDP, Fedora)
    def graph
      @g ||= RDF::Graph.new
    end

    # RDF::Graph without any back end (e.g. LDP, Fedora) triples
    def stripped_graph
      @stripped_graph ||= begin
        new_graph = RDF::LDP.remove_ldp_triples (RDF::FCRepo4.remove_fedora_triples(graph))
      end
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