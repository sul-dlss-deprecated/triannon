require_dependency "triannon/application_controller"

module Triannon
  class SearchController < ApplicationController
    def find
      anno_graphs_array = solr_searcher.find(params)

      # send iiif_anno_list in appropriate format (jsonld, ttl, rdfxml ...)
      # possibly create Triannon::Search::Response class to do this
    end


  protected

    def solr_searcher
      @ss ||= Triannon::SolrSearcher.new
    end

  end # SearchController

end # Triannon
