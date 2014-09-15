module Cerberus::Annotations
  class Annotation < ActiveRecord::Base

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
