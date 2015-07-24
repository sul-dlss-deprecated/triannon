require 'spec_helper'
# These specs use the spec/auth_helpers by using the tag 'help: :auth'

describe 'AnnotationsAuthentication', :vcr, type: :request, help: :auth do

  before(:all) do
    @root_container = 'bar' # this one is configured for authorization
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

  let(:anno_json) {
    Triannon.annotation_fixture('body-chars-no-id.json')
  }

  let(:anno_data) {
    {
      'commit' => 'Create Annotation',
      'annotation' => { 'data' => anno_json }
    }
  }

  let(:access_token) {
    headers = json_payloads
    # 1. Obtain a client authorization code (short-lived token)
    post "/auth/client_identity", client_credentials.to_json, headers
    expect(response.status).to eql(200) # OK
    auth = JSON.parse(response.body)
    expect(auth.keys).to include('authorizationCode')
    auth_code = auth['authorizationCode']
    expect(auth_code).not_to be_nil
    # 2. The client POSTs user credentials.
    post "/auth/login?code=#{auth_code}", login_credentials.to_json, headers
    expect(response.status).to eql(200) # OK
    # 3. The client, on behalf of user, obtains a long-lived access token.
    get "/auth/access_token?code=#{auth_code}", accept_json
    expect(response.status).to eql(200) # OK
    access = JSON.parse(response.body)
    expect(access.keys).to include('accessToken')
    expect(access.keys).to include('tokenType')
    expect(access.keys).to include('expiresIn')
    access_code = access['accessToken']
    expect(access_code).not_to be_nil
    access_code
  }

  let(:create_annotation) {
    # CREATE a new annotation (using access token).
    post container_uri, anno_data.to_json, valid_token_headers
    expect(response.status).to eql(201) # OK
    anno_id = assigns(:annotation).id
    @ldp_testing_container_urls << "#{@root_container}/#{anno_id}"
    @solr_docs_from_testing << anno_id
    anno_id
  }

  let(:container_uri) {
    "/annotations/#{@root_container}"
  }

  let(:invalid_token_headers) {
    headers = json_payloads
    headers.merge( { 'Authorization' => "Bearer invalid_token" } )
  }

  let(:valid_token_headers) {
    headers = json_payloads
    headers.merge!( { 'Authorization' => "Bearer #{access_token}" } )
  }

  describe 'authorized annotation create/delete' do

    it 'succeeds with a valid access token' do
      # Using the access token, the client is authorized to
      # create and delete annotations in a container that allows
      # access for any workgroup in the user workgroups.
      # CREATE a new annotation (using access token).
      anno_id = create_annotation # see above
      anno_uri = "#{container_uri}/#{CGI.escape(anno_id)}"
      # DELETE an existing annotation.
      delete anno_uri, nil, valid_token_headers
      expect(response.status).to eql(204) # OK, no content
      # Check that it's gone (GET does not require access token).
      get anno_uri
      expect(response.status).to eql(410) # gone
    end

    it 'fails to create annotation without any access token' do
      no_token_headers = json_payloads
      post container_uri, anno_data.to_json, no_token_headers
      expect(response.status).to eql(401) # requires authentication
    end

    it 'fails to create annotation using an invalid access token' do
      access_token # create a valid access token
      post container_uri, anno_data.to_json, invalid_token_headers
      expect(response.status).to eql(403) # not authorized
    end

    it 'fails to delete annotation using an invalid access token' do
      anno_id = create_annotation
      anno_uri = "#{container_uri}/#{CGI.escape(anno_id)}"
      delete anno_uri, nil, invalid_token_headers
      expect(response.status).to eql(403) # not authorized
      # Check that it's still present.
      get anno_uri
      expect(response.status).to eql(200) # OK, still exists
    end

    it 'fails to delete annotation without an access token' do
      anno_id = create_annotation
      anno_uri = "#{container_uri}/#{CGI.escape(anno_id)}"
      no_token_headers = json_payloads
      delete anno_uri, nil, no_token_headers
      expect(response.status).to eql(401) # requires authentication
      # Check that it's still present.
      get anno_uri
      expect(response.status).to eql(200) # OK, still exists
    end

  end

end
