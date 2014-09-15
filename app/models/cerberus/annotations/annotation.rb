module Cerberus::Annotations
  class Annotation < ActiveRecord::Base

    def motivated_by
      # FIXME:  can have multiple motivations per spec 
      # http://www.openannotation.org/spec/core/core.html#Motivations
      s = rdf.find_all { |s| 
        s.predicate.to_s == "http://www.w3.org/ns/oa#motivatedBy"
      }.first
      s.object.to_str
    end

    def url
      json['@id'] if json
    end

    def rdf
      @rdf ||= JSON::LD::API.toRdf(json)
    end

    def graph
      @graph ||= RDF::Graph.new << rdf
    end

    private

    def json
      @json ||= JSON.parse(data) rescue nil
    end

  end
end
