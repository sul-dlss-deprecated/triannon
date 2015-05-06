require 'oa/graph'

# mixin methods
module OA
  class Graph

    # returns graph without any LDP-specific triples
    def self.remove_ldp_triples graph
      if graph && graph.is_a?(RDF::Graph) && graph.count > 0
        no_ldp_graph = RDF::Graph.new
        ldp_props = RDF::Vocab::LDP.properties.map {|p| p.to_s}
        graph.each { |stmt|
          no_ldp_graph << stmt unless ldp_props.include?(stmt.predicate.to_s) ||
                                      ldp_props.include?(stmt.object.to_s) ||
                                      ldp_props.include?(stmt.subject.to_s)
        }
        no_ldp_graph
      else
        graph
      end
    end

    # returns graph without any fedora-specific triples
    #  note that the Fedora vocab is not complete and also doesn't include modeshape
    def self.remove_fedora_triples graph
      if graph && graph.is_a?(RDF::Graph) && graph.count > 0
        no_fedora_graph = RDF::Graph.new
        fedora_props = RDF::Vocab::Fcrepo4.properties.map {|p| p.to_s}
        fedora_ns = "http://fedora.info/definitions"
        modeshape_ns = "http://www.jcp.org/jcr"
         # describable predates Fedora 4.1.1, but just in case ...
        fedora_describable = "http://purl.org/dc/elements/1.1/describable"
        graph.each { |stmt|
          no_fedora_graph << stmt unless fedora_props.include?(stmt.predicate.to_s) ||
                                      fedora_props.include?(stmt.object.to_s) ||
                                      fedora_props.include?(stmt.subject.to_s) ||
                                      stmt.predicate.to_s.match(fedora_ns) ||
                                      stmt.predicate.to_s.match(modeshape_ns) ||
                                      stmt.subject.to_s.match(fedora_ns) ||
                                      stmt.object.to_s.match(fedora_ns) ||
                                      stmt.object.to_s.match(modeshape_ns) ||
                                      stmt.object.to_s == (fedora_describable)
        }
        no_fedora_graph
      else
        graph
      end
    end

  end
end
