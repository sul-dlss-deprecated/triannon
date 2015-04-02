require_dependency "triannon/application_controller"

module Triannon
  class SearchController < ApplicationController
    
    def find
      anno_graphs_array = solr_searcher.find(params)

      # add id to iiif_anno_list
      list_hash = Triannon::IIIFAnnoList.anno_list(anno_graphs_array)
      list_hash["@id"] = request.original_url if list_hash
      
      # TODO: send iiif_anno_list in appropriate format (jsonld, ttl, rdfxml ...)
      # possibly create Triannon::Search::Response class to do this
      
      render :json => list_hash.to_json


=begin      
      # TODO:  json.set! "@context", Triannon::JsonldContext::OA_DATED_CONTEXT_URL - would this work?
      respond_to do |format|
        format.jsonld {
          context_url = context_url_from_accept ? context_url_from_accept : context_url_from_link
          if context_url && context_url == Triannon::JsonldContext::IIIF_CONTEXT_URL
            render_jsonld_per_context("iiif", "application/ld+json")
          else
            render_jsonld_per_context(params[:jsonld_context], "application/ld+json")
          end
        }
        format.ttl {
          accept_return_type = mime_type_from_accept(["application/x-turtle", "text/turtle"])
          render :body => @annotation.graph.to_ttl, content_type: accept_return_type if accept_return_type }
        format.rdfxml {
          accept_return_type = mime_type_from_accept(["application/rdf+xml", "text/rdf+xml", "text/rdf"])
          render :body => @annotation.graph.to_rdfxml, content_type: accept_return_type if accept_return_type }
        format.json {
          accept_return_type = mime_type_from_accept(["application/json", "text/x-json", "application/jsonrequest"])
          context_url = context_url_from_link ? context_url_from_link : context_url_from_accept
          if context_url && context_url == Triannon::JsonldContext::IIIF_CONTEXT_URL
            render_jsonld_per_context("iiif", accept_return_type)
          else
            render_jsonld_per_context(params[:jsonld_context], accept_return_type)
          end
        }
        format.xml {
          accept_return_type = mime_type_from_accept(["application/xml", "text/xml", "application/x-xml"])
          render :xml => @annotation.graph.to_rdfxml, content_type: accept_return_type if accept_return_type }
        format.html { render :show }
      end
=end      
      
    end


  protected

    def solr_searcher
      @ss ||= Triannon::SolrSearcher.new
    end

  end # SearchController

end # Triannon
