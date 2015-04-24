module Triannon

  class IIIFAnnoList

    # from http://iiif.io/api/presentation/2/annotationList_frame.json
    ANNO_LIST_FRAME = JSON.parse('
      {
          "@context" : "http://iiif.io/api/presentation/2/context.json",
          "@type": "sc:AnnotationList",
          "resources": [{
              "@type": "oa:Annotation",
              "on" : [{
                  "@embed" : false
              }]
          }]
      }')

    # from http://iiif.io/api/presentation/2/annotation_frame.json
    ANNO_FRAME = JSON.parse('
      {
        "@context" : "http://iiif.io/api/presentation/2/context.json",
        "@type": "oa:Annotation",
        "on" : [{
            "@embed" : false
        }]
      }')

# Class Methods ----------------------------------------------------------------

    # take an Array of annos as OA::Graph objects and return a Hash representation
    #    of IIIF Annotation List
    # @param [Array<OA::Graph>] tgraph_array annotations as OA::Graph objects
    # @return [Hash] IIIF Annotation List as a Hash, containing the annotations in the array
    def self.anno_list(tgraph_array)
      if tgraph_array
        result = {
          "@context" => OA::Graph::IIIF_CONTEXT_URL,
          "@type" => "sc:AnnotationList",
          "within" => {"@type" => "sc:Layer", "total" => tgraph_array.size },
          "resources" => tgraph_array.map { |g|
            embedded_body = JSON::LD::API.frame(JSON.parse(g.jsonld_iiif), ANNO_FRAME)
            resource = embedded_body["@graph"]
            if resource.is_a?(Array) && resource.size == 1
              resource = resource.first
            end
            resource
          }
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
