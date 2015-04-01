module Triannon

  class IIIFAnnoList

# Class Methods ----------------------------------------------------------------

    # take an Array of annos as Triannon::Graph objects and return a Hash representation
    #    of IIIF Annotation List
    # @param [Array<Triannon::Graph>] tgraph_array annotations as Triannon::Graph objects
    # @return [Hash] IIIF Annotation List as a Hash, containing the annotations in the array
    def self.anno_list(tgraph_array)
      if tgraph_array
        result = {
          "@context" => Triannon::JsonldContext::IIIF_CONTEXT_URL,
          "@type" => "sc:AnnotationList",
          "within" => {"@type" => "sc:Layer", "total" => tgraph_array.size },
          "resources" => tgraph_array.map { |g| JSON.parse(g.jsonld_iiif) }
        }
      
        # remove context from each anno as it is redundant
        result["resources"].each { |anno_hash|
          anno_hash.delete("@context")
        }
        result
      end
    end

  end
end