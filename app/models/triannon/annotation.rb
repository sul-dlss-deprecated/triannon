module Triannon
  class Annotation
    include ActiveModel::Model
    
    define_model_callbacks :save, :destroy
    after_save :solr_save
    after_destroy :solr_delete

    attr_accessor :id, :data, :expected_content_type

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

    # @param [String] id the unique id of the annotation.  Can include base_uri prefix or omit it.
    def self.find(id)
      oa_graph = Triannon::LdpLoader.load id
      anno = Triannon::Annotation.new
      anno.graph = oa_graph
      anno.id = id
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
        @id = Triannon::LdpWriter.create_anno self if graph && graph.size > 2
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

    # @param either a Triannon::Graph or RDF::Graph object
    def graph= g
      if g.is_a? Triannon::Graph
        @graph = g
      elsif g.kind_of? RDF::Graph
        @graph = Triannon::Graph.new g
      end
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

    # Add annotation to Solr as a Solr document
    def solr_save
      # to be certain we are in sync, and to get the anno id within the graph, reload 
      # the graph from Trianon storage
      graph_from_storage = Triannon::LdpLoader.load id
      solr_hash = graph_from_storage.solr_hash
      solr_writer.add(solr_hash) if solr_hash && solr_hash.size > 0
    end

    # Delete annotation from Solr
    def solr_delete
      solr_writer.delete(id) if id
    end
    
private

    # loads RDF::Graph from data attribute.  If data is in json-ld or rdfxml, converts it to turtle.
    def data_to_graph
      if data
        data.strip!
        if expected_content_type
          case Mime::Type.lookup(expected_content_type).symbol
            when :jsonld, :json
              g = jsonld_to_graph
            when :ttl
              g = ttl_to_graph
            when :rdfxml, :xml
              g = rdfxml_to_graph
            else
              g = nil
          end
        else # infer the content type from the content itself
          case data
            # \A and \Z and m are needed instead of ^$ due to \n in data
            when /\A\{.+\}\Z/m  
              g = jsonld_to_graph
            when /\A<.+>\Z/m
              g = rdfxml_to_graph
            when /\.\Z/ # turtle ends in period
              g = ttl_to_graph
            else
              g = nil
          end
        end
      end
      g
    end
    
    # create and load an RDF::Graph object from turtle in data attrib
    # @return [RDF::Graph] populated RDF::Graph object, or nil
    def ttl_to_graph
      g = RDF::Graph.new.from_ttl(data)
      g = nil if g && g.size == 0
      g
    end

    # create and load an RDF::Graph object from jsonld in data attrib
    # SIDE EFFECT: converts data to turtle for LdpWriter
    # @return [RDF::Graph] populated RDF::Graph object, or nil
    def jsonld_to_graph
      # need to do this to avoid external lookup of jsonld context
      g ||= RDF::Graph.new << JSON::LD::API.toRdf(json_ld) if json_ld
      g = nil if g && g.size == 0
      self.data = g.dump(:ttl) if g  # LdpWriter expects ttl
      g
    end

    # create and load an RDF::Graph object from rdfxml in data attrib
    # SIDE EFFECT: converts data to turtle for LdpWriter
    # @return [RDF::Graph] populated RDF::Graph object, or nil
    def rdfxml_to_graph
      g = RDF::Graph.new.from_rdfxml(data)
      g = nil if g && g.size == 0
      self.data = g.dump(:ttl) if g  # LdpWriter expects ttl
      g
    end

    # avoid external lookup of jsonld context by putting it inline
    # @return [Hash] the parsed json after the context is put inline
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

    def solr_writer
      @sw ||= Triannon::SolrWriter.new
    end

  end
end
