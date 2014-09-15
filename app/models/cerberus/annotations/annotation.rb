module Cerberus::Annotations
  class Annotation < ActiveRecord::Base

    def url
      json['@id'] if json
    end

    def type
      s = rdf.detect { |s| 
        s.predicate.to_s == "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
      }.object.to_str
    end

    def motivated_by
      # FIXME:  can have multiple motivations per spec  (examples 9, 10, 11)
      # http://www.openannotation.org/spec/core/core.html#Motivations
      s = rdf.find_all { |s| 
        s.predicate.to_s == "http://www.w3.org/ns/oa#motivatedBy"
      }.first
      s.object.to_str
    end

    def rdf
      @rdf ||= JSON::LD::API.toRdf(json) if json
    end

    def graph
      @graph ||= RDF::Graph.new << rdf if json
    end

    private

    def json
      @json ||= JSON.parse(data) rescue nil
    end

  end
end
