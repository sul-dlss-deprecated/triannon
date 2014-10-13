
module Triannon
  class AnnotationLdp

    attr_accessor :annotation_data, :body_data, :target_data


    def body_uri
      result = bg.query []
    end

    def base_graph
      @bg ||= base_graph_from_data
    end

    def base_uri
      res = base_graph.query anno_query
      res.first.s
    end

    def body_uri
      q = anno_query
      q << [:s, RDF::OpenAnnotation.hasBody, :uri]
      res = base_graph.query q
      res.first.uri
    end

    def anno_query
      q = RDF::Query.new
      q << [:s, RDF.type, RDF::OpenAnnotation.Annotation]
    end

    def base_graph_from_data
      g = RDF::Graph.new
      g.from_ttl @annotation_data
      g
    end
  end
end