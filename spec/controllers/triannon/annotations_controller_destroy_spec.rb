require 'spec_helper'

describe Triannon::AnnotationsController, :vcr, type: :controller do

  routes { Triannon::Engine.routes }

  context '#destroy' do
    before(:all) do
      @root_container = 'anno_controller_destroy_specs'
      @solr_docs_from_testing = []
      vcr_cassette_name = "Triannon_AnnotationsController/_destroy/before_spec"
      create_root_container(@root_container, vcr_cassette_name)
    end
    after(:all) do
      ldp_testing_containers = ["#{spec_ldp_url}/#{spec_uber_cont}/#{@root_container}"]
      vcr_cassette_name = "Triannon_AnnotationsController/_destroy/after_spec"
      delete_test_objects(ldp_testing_containers, @solr_docs_from_testing, @root_container, vcr_cassette_name)
    end

    it "returns 204 status code for successful delete" do
      anno = Triannon::Annotation.new({data: Triannon.annotation_fixture("body-chars.ttl"), root_container: @root_container})
      anno_id = anno.save
      @solr_docs_from_testing << anno_id
      my_anno = Triannon::Annotation.find(anno_id, @root_container)
      delete :destroy, anno_root: @root_container, id: anno_id
      expect(response.status).to eq 204
    end
    context 'non-existent id' do
      let(:fake_id) { "foo" }

      it "gives 404 resp code" do
        delete :destroy, anno_root: @root_container, id: fake_id
        expect(response.status).to eq 404
      end
      it "gives html response" do
        delete :destroy, anno_root: @root_container, id: fake_id
        expect(response.content_type).to eql "text/html"
      end
      it "has useful info in the responose" do
        delete :destroy, anno_root: @root_container, id: fake_id
        expect(response.body).to match fake_id
        expect(response.body).to match "404"
        expect(response.body).to match "Not Found"
      end
    end
    context 'SearchError' do
      let(:triannon_err_msg) { "triannon msg" }
      let(:fake_id) {"blargle"}
      before(:example) do
        allow(Triannon::Annotation).to receive(:find)
        allow(Triannon::LdpWriter).to receive(:delete_anno)
      end

      context 'with Solr HTTP info' do
        let(:search_resp_code) { 409 }
        let(:search_resp_body) { "body of error resp from search server" }
        let(:search_error) { Triannon::SearchError.new(triannon_err_msg, search_resp_code, search_resp_body)}
        it "gives Solr's resp code" do
          allow(subject).to receive(:destroy).and_raise(search_error)
          delete :destroy, anno_root: @root_container, id: fake_id
          expect(response.status).to eq search_resp_code
        end
        it "gives html response" do
          allow(subject).to receive(:destroy).and_raise(search_error)
          delete :destroy, anno_root: @root_container, id: fake_id
          expect(response.content_type).to eql "text/html"
        end
        it "has useful info in the responose" do
          allow(subject).to receive(:destroy).and_raise(search_error)
          delete :destroy, anno_root: @root_container, id: fake_id
          expect(response.body).to match search_resp_body
          expect(response.body).to match triannon_err_msg
        end
      end

      context 'no Solr HTTP info' do
        let(:search_error) { Triannon::SearchError.new(triannon_err_msg)}
        it "gives 400 resp code" do
          allow(subject).to receive(:destroy).and_raise(search_error)
          delete :destroy, anno_root: @root_container, id: fake_id
          expect(response.status).to eq 400
        end
        it "gives html response" do
          allow(subject).to receive(:destroy).and_raise(search_error)
          delete :destroy, anno_root: @root_container, id: fake_id
          expect(response.content_type).to eql "text/html"
        end
        it "has useful info in the responose" do
          allow(subject).to receive(:destroy).and_raise(search_error)
          delete :destroy, anno_root: @root_container, id: fake_id
          expect(response.body).to match triannon_err_msg
        end
      end
    end # SearchError
  end

end
