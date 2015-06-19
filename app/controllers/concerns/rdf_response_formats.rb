# methods to support RDF response formats
module RdfResponseFormats
  extend ActiveSupport::Concern

  # find first mime type from request.accept that matches return mime type
  def mime_type_from_accept(return_mime_types)
    @mime_type_from_accept ||= begin
      if request.accept && request.accept.is_a?(String)
        accept_mime_types = request.accept.split(',')
        accept_mime_types.each { |mime_type|
          mime_str = mime_type.split("; profile=").first.strip
          if return_mime_types.include? mime_str
            return mime_str
          end
        }
      end
    end
  end

  # set format to jsonld if it isn't already set
  def default_format_jsonld
    if ((!request.accept || request.accept.empty?) && (!params[:format] || params[:format].empty?))
      request.format = "jsonld"
    end
  end

  # parse the Accept HTTP header for the value of profile if it is a request for jsonld or json.
  #   e.g. Accept: application/ld+json; profile="http://www.w3.org/ns/oa-context-20130208.json"
  # @return [String] url for jsonld @context or nil if missing or non-jsonld/json format
  def context_url_from_accept
    if request.format == "jsonld" || request.format == "json"
      accept_str = request.accept
      if accept_str && accept_str.split("profile=") && accept_str.split("profile=").last
        context_url = accept_str.split("profile=").last.strip
        context_url = context_url[1, context_url.size] if context_url.start_with?('"')
        context_url = context_url[0, context_url.size-1] if context_url.end_with?('"')
        case context_url
          when OA::Graph::OA_DATED_CONTEXT_URL,
            OA::Graph::OA_CONTEXT_URL,
            OA::Graph::IIIF_CONTEXT_URL
            context_url
          else
            nil
        end
      end
    end
  end

  # parse the Accept HTTP Link for the value of rel if it is a request for jsonld or json
  #   e.g. Link: http://www.w3.org/ns/oa.json; rel="http://www.w3.org/ns/json-ld#context"; type="application/ld+json"
  #   note that the "type" part is optional
  # @return [String] url for jsonld @context or nil if missing or non-jsonld/json format
  def context_url_from_link
    if request.format == "jsonld" || request.format == "json"
      link_str = request.headers["Link"]
      if link_str && link_str.split("; rel=") && link_str.split("; rel=").first
        context_url = link_str.split("; rel=").first.strip
        case context_url
          when OA::Graph::OA_DATED_CONTEXT_URL,
            OA::Graph::OA_CONTEXT_URL,
            OA::Graph::IIIF_CONTEXT_URL
            context_url
          else
            nil
        end
      end
    end
  end

end
