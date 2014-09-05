module Cerberus::Annotations
  class Annotation
    class <<self
      def from_json json
        graph = RDF::Graph.new << JSON::LD::API.toRdf(JSON.parse(json))
        self.new graph
      end
    end

    attr_reader :graph

    def initialize graph
      @graph = graph
    end
    
  end
end
