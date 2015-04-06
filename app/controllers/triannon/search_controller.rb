require_dependency "triannon/application_controller"

module Triannon
  class SearchController < ApplicationController
    include RdfResponseFormats

    before_action :default_format_jsonld, only: [:find]

    def find
      anno_graphs_array = solr_searcher.find(params)

      # add id to iiif_anno_list
      @list_hash = Triannon::IIIFAnnoList.anno_list(anno_graphs_array)
      @list_hash["@id"] = request.original_url if @list_hash

      respond_to do |format|
        format.jsonld { render :json => @list_hash.to_json, content_type: "application/ld+json" }
        format.ttl {
          accept_return_type = mime_type_from_accept(["application/x-turtle", "text/turtle"])
          render :body => RDF::Graph.new.from_jsonld(@list_hash.to_json).to_ttl, content_type: accept_return_type if accept_return_type
        }
        format.rdfxml {
          accept_return_type = mime_type_from_accept(["application/rdf+xml", "text/rdf+xml", "text/rdf"])
          render :body => RDF::Graph.new.from_jsonld(@list_hash.to_json).to_rdfxml, content_type: accept_return_type if accept_return_type }
        format.json {
          accept_return_type = mime_type_from_accept(["application/json", "text/x-json", "application/jsonrequest"])
          render :json => @list_hash.to_json, content_type: accept_return_type
        }
        format.xml {
          accept_return_type = mime_type_from_accept(["application/xml", "text/xml", "application/x-xml"])
          render :xml => RDF::Graph.new.from_jsonld(@list_hash.to_json).to_rdfxml, content_type: accept_return_type if accept_return_type }
        format.html { render :find }
      end
    end


  protected

    def solr_searcher
      @ss ||= Triannon::SolrSearcher.new
    end


  end # SearchController

end # Triannon
