module Triannon
  class Annotation
    include ActiveModel::Model
    
    define_model_callbacks :save, :destroy
    after_save :solr_save
    after_destroy :solr_delete

    attr_accessor :id, :data

    validates_each :data do |record, attr, value|
      record.errors.add attr, 'less than 30 chars' if value.to_s.length < 30
    end

    # full validation should be optional?
    #   minimal:  a subject with the right type and a hasTarget?  (see url)
    # and perhaps modeled on this:
    #   https://github.com/uq-eresearch/lorestore/blob/3e9aa1c69aafd3692c69aa39c64bfdc32b757892/src/main/resources/OAConstraintsSPARQL.json


    # Class Methods ----------------------------------------------------------------
  
    def self.create(attrs = {})
      a = Triannon::Annotation.new attrs
      a.save
      a
    end

    def self.find(key)
      oa_graph = Triannon::LdpLoader.load key
      anno = Triannon::Annotation.new
      anno.graph = oa_graph
      anno.id = key
      anno
    end

    def self.all
      Triannon::LdpLoader.find_all
    end

    # Instance Methods ----------------------------------------------------------------

    def save
      _run_save_callbacks do
        # check if valid?
        graph
        @id = Triannon::LdpWriter.create_anno self
      end
    end

    def destroy
      _run_destroy_callbacks do
        Triannon::LdpWriter.delete_anno @id
      end
    end

    def persisted?
      self.id.present?
    end

    def graph
      @graph ||= begin
        g = data_to_graph
        Triannon::Graph.new g if g.kind_of? RDF::Graph
      end
    end

    # @param [RDF::Graph]
    def graph= g
      @graph = Triannon::Graph.new g if g.kind_of? RDF::Graph
    end
    
    # @return json-ld representation of anno with OpenAnnotation context as a url
    def jsonld_oa
      graph.jsonld_oa
    end
    
    # @return json-ld representation of anno with IIIF context as a url
    def jsonld_iiif
      graph.jsonld_iiif
    end

    # @return [String] the id of this annotation as a url or nil if no graph
    def id_as_url
      graph.id_as_url if graph_exists?
    end

    # @return [Array<String>] of urls expressing the OA motivated_by values or nil if no graph
    def motivated_by
      graph.motivated_by if graph_exists?
    end

protected

    # TODO: WRITE_COMMENTS_AND_TESTS_FOR_THIS_METHOD
    def solr_save
#      puts "TO DO: send add to Solr (after save)"
#      pp solr_hash
    end

    # TODO: WRITE_COMMENTS_AND_TESTS_FOR_THIS_METHOD
    def solr_delete
#      puts "TO DO: send delete to Solr (after destroy)"
    end
    
    # TODO: WRITE_COMMENTS_AND_TESTS_FOR_THIS_METHOD
    # TODO:  re-usable as part of Triannon::Graph class?
    # 
    # @return [Hash] a hash to be written to Solr, populated appropriately
    def solr_hash
      doc_hash = {}
      tid = url.sub(Triannon.config[:ldp_url], "")
      tid.sub(/^\//, "")
      doc_hash[:id] = tid
      # use short strings for motivation field
      doc_hash[:motivation] = motivated_by.map { |m| m.sub(RDF::OpenAnnotation.to_s, "") }
      # date field format: 1995-12-31T23:59:59Z; or w fractional seconds: 1995-12-31T23:59:59.999Z
#      doc_hash[:annotated_at] =
#      doc_hash[:annotated_by_stem]
      doc_hash[:target_url] = graph.predicate_urls RDF::OpenAnnotation.hasTarget
      doc_hash[:target_type] = ['external_URI'] if doc_hash[:target_url].size > 0
      doc_hash[:body_url] = graph.predicate_urls RDF::OpenAnnotation.hasBody
      doc_hash[:body_type] = []
      doc_hash[:body_type] << 'external_URI' if doc_hash[:body_url].size > 0
      doc_hash[:body_chars_exact] = graph.body_chars
      doc_hash[:body_type] << 'content_as_text' if doc_hash[:body_chars_exact].size > 0
      doc_hash[:body_type] << 'no_body' if doc_hash[:body_type].size == 0
      doc_hash[:anno_jsonld] = jsonld_oa
      doc_hash
    end
    
private

    # loads RDF::Graph from data attribute.  If data is in json-ld, converts it to turtle.
    def data_to_graph
      if data
        data.strip!
        case data
          when /\A\{.+\}\Z/m  # (Note:  \A and \Z and m are needed instead of ^$ due to \n in data)
            g ||= RDF::Graph.new << JSON::LD::API.toRdf(json_ld) if json_ld
            self.data = g.dump(:ttl) if g
          when /\A<.+>\Z/m # (Note:  \A and \Z and m are needed instead of ^$ due to \n in data)
            g = RDF::Graph.new
            g.from_rdfxml(data)
            g = nil if g.size == 0
          when /\.\Z/ #  (Note:  \Z is needed instead of $ due to \n in data)
            # turtle ends in period
            g = RDF::Graph.new
            g.from_ttl(data)
            g = nil if g.size == 0
        end
      end
      g
    end
    
    def json_ld
      if data.match(/"@context"\s*\:\s*"http\:\/\/www\.w3\.org\/ns\/oa-context-20130208\.json"/)
        data.sub!("\"http://www.w3.org/ns/oa-context-20130208.json\"", Triannon::JsonldContext.oa_context)
      elsif data.match(/"@context"\s*\:\s*"http\:\/\/www\.w3\.org\/ns\/oa\.jsonld"/)
        data.sub!("\"http://www.w3.org/ns/oa.jsonld\"", Triannon::JsonldContext.oa_context)
      elsif data.match(/"@context"\s*\:\s*"http\:\/\/iiif\.io\/api\/presentation\/2\/context\.json"/)
        data.sub!("\"http://iiif.io/api/presentation/2/context.json\"", Triannon::JsonldContext.iiif_context)
      end
      @json_ld ||= JSON.parse(data) rescue nil
    end

    def graph_exists?
      graph && graph.size > 0
    end

  end
end
