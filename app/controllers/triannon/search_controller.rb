require_dependency "triannon/application_controller"

module Triannon
  class SearchController < ApplicationController
    def find
      # Ultimately:
      #   search method:
      #     1.  converts controller params to solr params
      #     2.  sends request to Solr
      #     3.  converts Solr response object to array of anno graphs
      # anno_graphs_array = solr_searcher.search(params)

      solr_response = solr_searcher.search(Triannon::SolrSearcher.solr_params(params))

      # send iiif_anno_list in appropriate format (jsonld, ttl, rdfxml ...)
      # possibly create Triannon::Search::Response class to do this
    end


  protected

    def solr_searcher
      @ss ||= Triannon::SolrSearcher.new
    end

  end # SearchController

end # Triannon
