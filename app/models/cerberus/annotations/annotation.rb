module Cerberus::Annotations
  class Annotation
    class <<self
      def from_json json
        graph = RDF::Graph.new << JSON::LD::API.toRdf(JSON.parse(json))
        self.new graph
      end
    end

    def initialize graph
      @graph = graph
    end
  end
end
