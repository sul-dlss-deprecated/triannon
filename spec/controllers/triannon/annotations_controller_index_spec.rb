require 'spec_helper'

describe Triannon::AnnotationsController, :vcr, type: :controller do

  routes { Triannon::Engine.routes }

  context '#index' do

    context "anno_root param is empty string" do
      it "redirects to search#find" do
        get :index, anno_root: ""
        expect(response).to redirect_to('/search/')
      end
      it "response code of 302 due to redirect" do
        get :index, anno_root: ""
        expect(response.status).to be 302
      end
    end

    context "anno_root param is existing root container" do
      before(:all) do
        @root_container = 'anno_controller_index_specs'
        vcr_cassette_name = "Triannon_AnnotationsController/_index/before_spec"
        create_root_container(@root_container, vcr_cassette_name)
      end
      after(:all) do
        ldp_testing_container_urls = ["#{spec_ldp_url}/#{spec_uber_cont}/#{@root_container}"]
        vcr_cassette_name = "Triannon_AnnotationsController/_index/after_spec"
        delete_test_objects(ldp_testing_container_urls, [], @root_container, vcr_cassette_name)
      end

      it "redirects to /search/anno_root param" do
        get :index, anno_root: @root_container
        expect(response).to redirect_to("/search/#{@root_container}")
      end
      it "response code of 302 due to redirect" do
        get :index, anno_root: @root_container
        expect(response.status).to be 302
      end
    end

    context "anno_root param is non-existent root container" do
      let(:root_container) {'blargle'}
      it "redirects to /search/anno_root" do
        get :index, anno_root: root_container
        expect(response).to redirect_to("/search/#{root_container}")
      end
      it "response code of 302 due to redirect" do
        get :index, anno_root: root_container
        expect(response.status).to be 302
      end
    end
  end

end
