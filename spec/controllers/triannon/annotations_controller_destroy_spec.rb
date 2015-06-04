require 'spec_helper'

describe Triannon::AnnotationsController, :vcr, type: :controller do

  routes { Triannon::Engine.routes }

  context '#destroy' do
    before(:all) do
      @cntnrs_to_delete_after_testing = []
      @solr_doc_ids_to_delete_after_testing = []
      @ldp_url = Triannon.config[:ldp]['url'].strip
      @ldp_url.chop! if @ldp_url.end_with?('/')
      @uber_cont = Triannon.config[:ldp]['uber_container'].strip
      @uber_cont = @uber_cont[1..-1] if @uber_cont.start_with?('/')
      @uber_cont.chop! if @uber_cont.end_with?('/')
      uber_root_url = "#{@ldp_url}/#{@uber_cont}"
      @root_container = 'anno_controller_destroy_specs'
      @root_url = "#{uber_root_url}/#{@root_container}"
      cassette_name = "Triannon_AnnotationsController/_destroy/before_spec"
      VCR.insert_cassette(cassette_name)
      begin
        Triannon::LdpWriter.create_basic_container(nil, @uber_cont)
        Triannon::LdpWriter.create_basic_container(@uber_cont, @root_container)
      rescue Faraday::ConnectionFailed
        # probably here due to vcr cassette
      end
      VCR.eject_cassette(cassette_name)
    end
    after(:all) do
      cassette_name = "Triannon_AnnotationsController/_destroy/after_spec"
      VCR.insert_cassette(cassette_name)
      @cntnrs_to_delete_after_testing << "#{@root_url}"
      @cntnrs_to_delete_after_testing.uniq.each { |cont_url|
        begin
          if Triannon::LdpWriter.container_exist?(cont_url.split("#{@ldp_url}/").last)
            Triannon::LdpWriter.delete_container cont_url
            Faraday.new(url: "#{cont_url}/fcr:tombstone").delete
          end
        rescue Triannon::LDPStorageError => e
          # probably here due to parent container being deleted first
        rescue Faraday::ConnectionFailed
          # probably here due to vcr cassette
        end
      }
      rsolr_client = RSolr.connect :url => Triannon.config[:solr_url]
      @solr_doc_ids_to_delete_after_testing.each { |solr_doc_id|
        rsolr_client.delete_by_id("#{@root_container}/#{solr_doc_id}")
      }
      rsolr_client.commit
      VCR.eject_cassette(cassette_name)
    end

    it "returns 204 status code for successful delete" do
      anno = Triannon::Annotation.new({data: Triannon.annotation_fixture("body-chars.ttl"), root_container: @root_container})
      anno_id = anno.save
      @solr_doc_ids_to_delete_after_testing << anno_id
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
