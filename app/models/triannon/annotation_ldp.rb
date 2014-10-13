
module Triannon
  class AnnotationLdp

    def body_uri
      result = bg.query []
    end

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

    def add_body body_data

    end

    def anno_query
      q = RDF::Query.new
      q << [:s, RDF.type, RDF::OpenAnnotation.Annotation]
    end

    def graph_from_data
      g = RDF::Graph.new
      g.from_ttl @annotation_data
      g
    end

    def load_data_into_graph ttl
      graph.from_ttl ttl
    end
  end
end