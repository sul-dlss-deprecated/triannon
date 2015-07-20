require 'spec_helper'
# These specs use the spec/auth_helpers by using the tag 'help: :auth'

describe 'Annotations Auth', :vcr, type: :request, help: :auth do

  let(:ttl_data) {Triannon.annotation_fixture("body-chars.ttl")}

  before(:all) do
    @root_container = 'bar'
    vcr_cassette_name = "Triannon_AnnotationsController/_auth/before_spec"
    create_root_container(@root_container, vcr_cassette_name)
    @ldp_testing_container_urls = []
    @solr_docs_from_testing = []
  end

  after(:all) do
    @ldp_testing_container_urls << "#{spec_ldp_url}/#{spec_uber_cont}/#{@root_container}"
    vcr_cassette_name = "Triannon_AnnotationsController/_auth/after_spec"
    delete_test_objects(@ldp_testing_container_urls, @solr_docs_from_testing, @root_container, vcr_cassette_name)
  end

  # ApplicationController#authorize should be available to
  # any controllers; it is tested here in the context of annotations.
  describe '#authorize' do

    it 'requires an access token for creating annotations'

    # it 'requires an access token for creating annotations' do
    #   expect(Triannon::ApplicationController).to receive(:authorize).once
    #   expect(Triannon::ApplicationController).to receive(:authorized_workgroup?)
    #   options = { 'Authorization' => "Bearer #{access_token}" }
    #   post '/annotations/bar', ttl_data, options
    #   expect(response.status).to eq 201
    #   anno_id = assigns(:annotation).id
    #   @ldp_testing_container_urls << "#{@root_container}/#{anno_id}"
    #   @solr_docs_from_testing << anno_id
    # end


    it 'requires an access token to delete annotations'

    # it 'requires an access token to delete annotations' do
    #   anno = Triannon::Annotation.new({
    #     data: ttl_data,
    #     root_container: @root_container
    #     })
    #   anno_id = anno.save
    #   @solr_docs_from_testing << anno_id
    #   Triannon::Annotation.find(@root_container, anno_id)
    #   expect(controller).to receive(:authorize).once
    #   expect(controller).to receive(:authorized_workgroup?)
    #   options = { 'Authorization' => "Bearer #{access_token}" }
    #   delete "/anno/#{@root_container}/#{anno_id}", options
    #   expect(response.status).to eq 204
    # end

  end

end
