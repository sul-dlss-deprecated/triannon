module Triannon
  class SolrSearcher
    
    # convert RSolr::Response object into an array of RDF::Graph objects,
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


    def initialize
      @rsolr_client = RSolr.connect :url => Triannon.config[:solr_url]
      @logger = Rails.logger
      @max_retries = Triannon.config[:max_solr_retries] || 5
      @base_sleep_seconds = Triannon.config[:base_sleep_seconds] || 1
      @max_sleep_seconds = Triannon.config[:max_sleep_seconds] || 5
    end

    # Ultimately:
    #   search method:
    #     1.  converts controller params to solr params
    #     2.  sends request to Solr
    #     3.  converts Solr response object to array of anno graphs
    # anno_graphs_arry = solr_searcher.search(params)



    # send params to Solr 'select' with POST, retrying if an error occurs.
    # See https://github.com/ooyala/retries for info on with_retries.
    # @param [Hash] solr_params the params to send to Solr
    # @return # what should it return???
    def search(solr_params = {})
      handler = Proc.new do |exception, attempt_cnt, total_delay|
        @logger.debug "#{exception.inspect} on Solr search attempt #{attempt_cnt} for #{solr_params.inspect}"
      end

      response = nil
      with_retries(:handler => handler,
                    :max_tries => @max_retries,
                    :base_sleep_seconds => @base_sleep_seconds,
                    :max_sleep_seconds => @max_sleep_seconds) do |attempt|
        @logger.debug "Solr search attempt #{attempt} for #{solr_params.inspect}"
        # use POST in case of long params
        response = @rsolr_client.post 'select', :params => solr_params
        @logger.info "Successfully searched Solr on attempt #{attempt}"
      end
      response
    end


  end
end