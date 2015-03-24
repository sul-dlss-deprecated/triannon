require 'spec_helper'

describe Triannon::SearchController, :vcr, type: :controller do

  routes { Triannon::Engine.routes }

  describe "GET find" do
    it "returns http success" do
      get :find
      expect(response).to have_http_status(:success)
    end
=begin TODO: implement find action in controller
    it "translates the params to Solr params" do
      fail "test to be implemented"
    end
    it "sends a search to Solr" do
      fail "test to be implemented"
    end
    it "reads each anno in the Solr response" do
      fail "test to be implemented"
    end
    it "returns a IIIF Annotation List" do
      fail "test to be implemented"
    end
    it "returns jsonld annos in IIIF context" do
      fail "test to be implemented"
    end
    context 'response formats' do
      context 'jsonld context' do
 
      end
    end
=end
  end # GET find

end
