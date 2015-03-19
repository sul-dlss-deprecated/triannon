module Triannon
  class SolrWriter
    
    def initialize
      @rsolr_client = RSolr.connect :url => Triannon.config[:solr_url]
      @logger = Rails.logger
      @max_retries = Triannon.config[:max_solr_retries] || 5
      @base_sleep_seconds = Triannon.config[:base_sleep_seconds] || 1
      @max_sleep_seconds = Triannon.config[:max_sleep_seconds] || 5
    end
    
    # Add the document to Solr, retrying if an error occurs.
    # See https://github.com/ooyala/retries for info on with_retries.
    # @param [Hash] doc a Hash representation of the Solr document to be added
    def add(doc)
      id = doc[:id]

      handler = Proc.new do |exception, attempt_cnt, total_delay|
        @logger.debug "#{exception.inspect} on Solr add attempt #{attempt_cnt} for #{id}"
      end

      with_retries(:handler => handler, 
                    :max_tries => @max_retries, 
                    :base_sleep_seconds => @base_sleep_seconds, 
                    :max_sleep_seconds => @max_sleep_seconds) do |attempt|
        @logger.debug "Solr add attempt #{attempt} for #{id}"
        # add it and commit within 0.5 seconds
        @rsolr_client.add(doc, :add_attributes => {:commitWithin => 500})
        @logger.info "Successfully indexed #{id} to Solr on attempt #{attempt}"
      end
    end
    
    # Delete the document from Solr, retrying if an error occurs.
    # See https://github.com/ooyala/retries for info on with_retries.
    # @param [String] id the id of the Solr document to be deleted
    def delete(id)
      handler = Proc.new do |exception, attempt_cnt, total_delay|
        @logger.debug "#{exception.inspect} on Solr delete attempt #{attempt_cnt} for #{id}"
      end  

      with_retries(:handler => handler, 
                    :max_tries => @max_retries, 
                    :base_sleep_seconds => @base_sleep_seconds, 
                    :max_sleep_seconds => @max_sleep_seconds) do |attempt|
        @logger.debug "Solr delete attempt #{attempt} for #{id}"
        @rsolr_client.delete_by_id(id)
        @rsolr_client.commit
        @logger.info "Successfully deleted #{id} from Solr"
      end      
    end
    
  end
end