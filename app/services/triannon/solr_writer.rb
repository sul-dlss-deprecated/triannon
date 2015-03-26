module Triannon
  class SolrWriter

    # DO NOT CALL before anno is stored: the graph should have an assigned url for the
    #   @id of the root;  it shouldn't be a blank node
    #
    # Convert a Triannon::Graph object into a Hash suitable for writing to Solr.
    #
    # @param [Triannon::Graph] triannon_graph a populated Triannon::Graph object for a *stored* anno
    # @return [Hash] a hash to be written to Solr, populated appropriately
    def self.solr_hash(triannon_graph)
      doc_hash = {}
      triannon_id = triannon_graph.id_as_url
      if triannon_id
        # chars in Solr/Lucene query syntax are a big pain in Solr id fields, so we only use
        # the uuid portion of the Triannon anno id, not the full url
        solr_id = triannon_id.sub(Triannon.config[:triannon_base_url], "")
        doc_hash[:id] = solr_id.sub(/^\/*/, "") # remove first char slash(es) if present

        # use short strings for motivation field
        doc_hash[:motivation] = triannon_graph.motivated_by.map { |m| m.sub(RDF::OpenAnnotation.to_s, "") }

        # date field format: 1995-12-31T23:59:59Z; or w fractional seconds: 1995-12-31T23:59:59.999Z
        if triannon_graph.annotated_at
          begin
            dt = Time.parse(triannon_graph.annotated_at)
            doc_hash[:annotated_at] = dt.iso8601 if dt
          rescue ArgumentError
            # ignore invalid datestamps
          end
        end
        #doc_hash[:annotated_by_stem] # not yet implemented

        doc_hash[:target_url] = triannon_graph.predicate_urls RDF::OpenAnnotation.hasTarget
        # TODO: recognize more target types
        doc_hash[:target_type] = ['external_URI'] if doc_hash[:target_url].size > 0

        doc_hash[:body_url] = triannon_graph.predicate_urls RDF::OpenAnnotation.hasBody
        doc_hash[:body_type] = []
        doc_hash[:body_type] << 'external_URI' if doc_hash[:body_url].size > 0
        doc_hash[:body_chars_exact] = triannon_graph.body_chars.map {|bc| bc.strip}
        doc_hash[:body_type] << 'content_as_text' if doc_hash[:body_chars_exact].size > 0
        doc_hash[:body_type] << 'no_body' if doc_hash[:body_type].size == 0

        doc_hash[:anno_jsonld] = triannon_graph.jsonld_oa
      end
      doc_hash
    end


    def initialize
      @rsolr_client = RSolr.connect :url => Triannon.config[:solr_url]
      @logger = Rails.logger
      @max_retries = Triannon.config[:max_solr_retries] || 5
      @base_sleep_seconds = Triannon.config[:base_sleep_seconds] || 1
      @max_sleep_seconds = Triannon.config[:max_sleep_seconds] || 5
    end

    # Convert the Triannon::Graph to a Solr document hash, then call RSolr.add
    #  with the doc hash
    # @param [Triannon::Graph] tgraph anno represented as a Triannon::Graph
    def write(tgraph)
      doc_hash = self.class.solr_hash(tgraph) if tgraph && !tgraph.id_as_url.empty?
      add(doc_hash) if doc_hash && !doc_hash.empty?
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