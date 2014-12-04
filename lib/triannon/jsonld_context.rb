module Triannon
  class JsonldContext
    
    OA_CONTEXT_URL = "http://www.w3.org/ns/oa.jsonld"

    OA_DATED_CONTEXT_URL = "http://www.w3.org/ns/oa-context-20130208.json"
    
    IIIF_CONTEXT_URL = "http://iiif.io/api/presentation/2/context.json"

    # a crude way of locally caching context so we don't hammer w3c server for every jsonld parse
    def self.oa_context
      @@oa_context ||= File.read(File.dirname(__FILE__) + "/oa_context_20130208.json")
    end

    # a crude way of locally caching context so we don't hammer server for every jsonld parse
    def self.iiif_context
      @@iiif_context ||= File.read(File.dirname(__FILE__) + "/iiif_presentation_2_context.json")
    end
     
  end
end