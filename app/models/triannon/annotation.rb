module Triannon
  class Annotation
    include ActiveModel::Model

    attr_accessor :id, :data

    validates_each :data do |record, attr, value|
      record.errors.add attr, 'less than 30 chars' if value.to_s.length < 30
    end

    # full validation should be optional?
    #   minimal:  a subject with the right type and a hasTarget?  (see url)
    # and perhaps modeled on this:
    #   https://github.com/uq-eresearch/lorestore/blob/3e9aa1c69aafd3692c69aa39c64bfdc32b757892/src/main/resources/OAConstraintsSPARQL.json


    def persisted?
      self.id.present?
    end

    def url
      if graph_exists?
        solution = graph.query self.class.anno_query
        if solution && solution.size == 1
          solution.first.s.to_s
        # TODO:  raise exception if no URL?
        end
      end
    end

    # FIXME:  this should be part of validation:  RDF.type should be RDF::OpenAnnotation.Annotation
    def type
      if graph_exists?
        q = RDF::Query.new
        q << [:s, RDF::OpenAnnotation.hasTarget, nil] # must have a target
        q << [:s, RDF.type, :type]
        solution = graph.query q
        solution.distinct!
        if solution && solution.size == 1
          solution.first.type.to_s
        # TODO:  raise exception if no type?
        end
      end
    end

    def motivated_by
      if graph_exists?
        q = self.class.anno_query.dup
        q << [:s, RDF::OpenAnnotation.motivatedBy, :motivated_by]
        solution = graph.query q
        if solution && solution.size > 0
          motivations = []
          solution.each {|res|
            motivations << res.motivated_by.to_s
          }
          motivations
        # TODO:  raise exception if none?
        end
      end
    end

    def graph
      @graph ||= data_to_graph
    end

    def graph= g
      @graph = g
    end
    
    # @return json-ld representation of graph with OpenAnnotation context as a url
    def jsonld_oa
      inline_context = graph.dump(:jsonld, :context => Triannon::JsonldContext::OA_CONTEXT_URL)
      hash_from_json = JSON.parse(inline_context)
      hash_from_json["@context"] = Triannon::JsonldContext::OA_CONTEXT_URL
      hash_from_json.to_json
    end
    
    # @return json-ld representation of graph with IIIF context as a url
    def jsonld_iiif
      inline_context = graph.dump(:jsonld, :context => Triannon::JsonldContext::IIIF_CONTEXT_URL)
      hash_from_json = JSON.parse(inline_context)
      hash_from_json["@context"] = Triannon::JsonldContext::IIIF_CONTEXT_URL
      hash_from_json.to_json
    end

    # query for a subject with type of RDF::OpenAnnotation.Annotation
    def self.anno_query
      @anno_query ||= begin
        q = RDF::Query.new
        q << [:s, RDF.type, RDF::URI("http://www.w3.org/ns/oa#Annotation")]
      end
    end

    def self.create(attrs = {})
      a = Triannon::Annotation.new attrs
      a.save
      a
    end

    def save
      # check if valid?
      graph
      @id = Triannon::LdpCreator.create self
    end

    def destroy
      Triannon::LdpDestroyer.destroy @id
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
