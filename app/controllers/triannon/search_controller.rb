require_dependency "triannon/application_controller"

module Triannon
  class SearchController < ApplicationController
    def find
      # Ultimately:
      #   search method:
      #     1.  converts controller params to solr params
      #     2.  sends request to Solr
      #     3.  converts Solr response object to array of anno graphs
      # anno_graphs_arry = solr_searcher.search(params)

      solr_response = solr_searcher.search(solr_params)

      # send iiif_anno_list in appropriate format (jsonld, ttl, rdfxml ...)
      # possibly create Triannon::Search::Response class to do this
    end



    # The protected methods could live elsewhere, but it seems like overkill
    #   to put them in an ActiveSupport::Concern and it seems better here than
    #   in a helper, which is usually meant for views.
    #
    # Furthermore, abstract search service stuff was not created as this code
    #   currently doesn't need that abstraction and may never need it.
    protected


    # FIXME:  move this method to solr_searcher  service  as   .solr_params(controller_params)
    # @note hardcoded Solr search service expectation in generated search params
    # @note hardcoded mapping of REST params for /search to Solr params
    #
    # Convert action request params to appropriate params
    #   to be sent to the search service as part of a search request
    #
    # request params are given in "Annotation Lists in Triannon" by Robert Sanderson
    #   in Google Docs:
    #
    # - targetUri, value is a URI
    # - bodyUri, value is a URI
    # - bodyExact, value is a string
    # - bodyKeyword, value is a string
    # - bodyType, value is a URI
    # - motivatedBy, value is a URI (or just the fragment portion)
    # - annotatedBy, value is a URI
    # - annotatedAt, value is a datetime
    #
    # @return [Hash] params to send to Solr as a Hash
    def solr_params()
      solr_params_hash = {}
      q_terms_array = []
      fq_terms_array = []

      params.each_pair { |k, v|
        case k.downcase
          when 'targeturi'
            q_terms_array << q_terms_for_url("target_url", v)
          when 'bodyuri'
            q_terms_array << q_terms_for_url("body_url", v)
          when 'bodyexact'
            # no need to Solr escape value because it's in quotes
            q_terms_array << "body_chars_exact:\"#{v}\""
          when 'motivatedby'
            case
              when v.include?('#')
                # we want fragment portion of URL value only, as that
                # is what is in Solr
                fq_terms_array << "motivation:#{RSolr.solr_escape(v.sub(/^.*#/, ''))}"
              when v == "http://www.shared-canvas.org/ns/painting", v == "sc:painting"
                fq_terms_array << "motivation:painting"
              else
                fq_terms_array << "motivation:#{RSolr.solr_escape(v)}"
            end
          when 'bodykeyword'
            solr_params_hash[:kqf] = 'body_chars_exact^3 body_chars_unstem^2 body_chars_stem'
            solr_params_hash[:kpf] = 'body_chars_exact^15 body_chars_unstem^10 body_chars_stem^5'
            solr_params_hash[:kpf3] = 'body_chars_exact^9 body_chars_unstem^6 body_chars_stem^3'
            solr_params_hash[:kpf2] = 'body_chars_exact^6 body_chars_unstem^4 body_chars_stem^2'
            q_terms_array << '_query_:"{!dismax qf=$kqf pf=$kpf pf3=$kpf3 pf2=$kpf2}' + RSolr.solr_escape(v) + '"'

          # TODO: add'l params to implement:
          # targetType - fq
          # bodyType - fq
          # annotatedAt - fq (deal with time format and wildcard for specificity)
          # annotatedBy - q (may be incomplete string)
        end
      }

      q_terms_array.flatten
      if q_terms_array.size > 0
        solr_params_hash[:q] = q_terms_array.join(' AND ')
        solr_params_hash[:defType] = "lucene"
      end
      if fq_terms_array.size > 0
        solr_params_hash[:fq] = fq_terms_array
      end

      solr_params_hash

      # TODO:  integration tests for
      #  target_url with and without the scheme prefix
      #  target_url with and without fragment
      #  bodykeyword single terms, multiple terms, quoted strings ...

    end # solr_params


    # FIXME:  move this method to solr_searcher as class method
    # If the url contains a fragment, query terms should only match the exact 
    #   url given (with the specific fragment).  (i.e. foo.org#bar does not
    #   match foo.org)
    # If the url does NOT contain a fragment, query terms should match the
    #   url given (no fragment) AND any urls that are the same with a fragment
    #   added.  (i.e. foo.org  matches  foo.org#bar)
    # @param [String] fieldname the name of the Solr field to be searched with url as a value
    # @param [String] url the url value sought in the Solr field
    # @return [Array<String>] an array of query terms to be added to the Solr q argument
    def q_terms_for_url(fieldname, url)
      q_terms = []
      q_terms << "#{fieldname}:#{RSolr.solr_escape(url)}"
      if !url.include? '#'
        # Note: do NOT Solr escape the # (unnec) or the * (want Solr to view it as wildcard)
        q_terms << "#{fieldname}:#{RSolr.solr_escape(url)}#*"
      end
      q_terms
    end


    def solr_searcher
      @ss ||= Triannon::SolrSearcher.new
    end

  end # SearchController

end # Triannon
