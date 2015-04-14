module Triannon
  class SolrSearcher

    # convert RSolr::Response object into an array of Triannon::Graph objects,
    #   where each graph object contains a single annotation returned in the response docs
    # @param [Hash] rsolr_response an RSolr response to a query.  It's actually an
    #   RSolr::HashWithResponse but let's not quibble
    # @return [Array<Triannon::Graph>]
    def self.anno_graphs_array(rsolr_response)
      result = []
      # TODO: deal with Solr pagination
      rsolr_response['response']['docs'].each { |solr_doc_hash|
        result << Triannon::Graph.new(RDF::Graph.new.from_jsonld(solr_doc_hash['anno_jsonld']))
      }
      result
    end

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
    # @param [Hash<String => String>] controller_params params from Controller
    # @return [Hash] params to send to Solr as a Hash
    def self.solr_params(controller_params)
      solr_params_hash = {}
      q_terms_array = []
      fq_terms_array = []

      controller_params.each_pair { |k, v|
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


    # If the url contains a fragment, query terms should only match the exact
    #   url given (with the specific fragment).  (i.e. foo.org#bar does not
    #   match foo.org)
    # If the url does NOT contain a fragment, query terms should match the
    #   url given (no fragment) AND any urls that are the same with a fragment
    #   added.  (i.e. foo.org  matches  foo.org#bar)
    # @param [String] fieldname the name of the Solr field to be searched with url as a value
    # @param [String] url the url value sought in the Solr field
    # @return [Array<String>] an array of query terms to be added to the Solr q argument
    def self.q_terms_for_url(fieldname, url)
      q_terms = []
      q_terms << "#{fieldname}:#{RSolr.solr_escape(url)}"
      if !url.include? '#'
        # Note: do NOT Solr escape the # (unnec) or the * (want Solr to view it as wildcard)
        q_terms << "#{fieldname}:#{RSolr.solr_escape(url)}#*"
      end
      q_terms
    end


    attr_accessor :rsolr_client

    def initialize
      @rsolr_client = RSolr.connect :url => Triannon.config[:solr_url]
      @logger = Rails.logger
      @max_retries = Triannon.config[:max_solr_retries] || 5
      @base_sleep_seconds = Triannon.config[:base_sleep_seconds] || 1
      @max_sleep_seconds = Triannon.config[:max_sleep_seconds] || 5
    end

    #  to be called from controller:
    #     1.  converts controller params to solr params
    #     2.  sends request to Solr
    #     3.  converts Solr response object to array of anno graphs
    # @param [Hash<String => String>] controller_params params from Controller
    # @return [Array<Triannon::Graph>] array of Triannon::Graph objects,
    #   where each graph object contains a single annotation returned in the response docs
    def find(controller_params)
      solr_params = self.class.solr_params(controller_params)
      solr_response = search(solr_params)
      anno_graphs_array = self.class.anno_graphs_array(solr_response)
    end


    protected

    # send params to Solr 'select' with POST, retrying if an error occurs.
    # See https://github.com/ooyala/retries for info on with_retries.
    # @param [Hash] solr_params the params to send to Solr
    # @return RSolr::Response object
    def search(solr_params = {})
      handler = Proc.new do |exception, attempt_cnt, total_delay|
        @logger.debug "#{exception.inspect} on Solr search attempt #{attempt_cnt} for #{solr_params.inspect}"
        if exception.kind_of?(RSolr::Error::Http)
          # Note there are extra shenanigans b/c RSolr hijacks the Solr error to return RSolr Error
          raise Triannon::SearchError.new("error searching Solr with params #{solr_params.inspect}: #{exception.message}", exception.response[:status], exception.response[:body])
        elsif exception.kind_of?(StandardError)
          raise Triannon::SearchError.new("error searching Solr with params #{solr_params.inspect}: #{exception.message}")
        end
      end

      response = nil
      with_retries(:handler => handler,
                    :max_tries => @max_retries,
                    :base_sleep_seconds => @base_sleep_seconds,
                    :max_sleep_seconds => @max_sleep_seconds) do |attempt|
        @logger.debug "Solr search attempt #{attempt} for #{solr_params.inspect}"
        # use POST in case of long params
        #  RSolr throws RSolr::Error::Http for any Solr response without status 200 or 302
        response = @rsolr_client.post 'select', :params => solr_params
        @logger.info "Successfully searched Solr on attempt #{attempt}"
      end
      response
    end

  end
end