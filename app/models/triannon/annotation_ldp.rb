
module Triannon
  class AnnotationLdp

    def graph
      @g ||= RDF::Graph.new
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