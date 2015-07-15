require 'spec_helper'
# These specs use the spec/auth_helpers by using the tag 'help: :auth'

describe Triannon::AuthController, :vcr, type: :controller, help: :auth do

  routes { Triannon::Engine.routes }

  describe 'OPTIONS /auth/login' do
    let(:check_service) {
      json = JSON.parse(response.body)
      expect(json.keys).to eql(['service'])
      info = json['service']
      expect(info.keys).to eql(['@id','profile', 'label'])
      expect(info['profile']).to eql(@service_profile)
    }
    context 'accept JSON:' do
      before :each do
        set_json_headers
      end
      it 'returns login information, with no user logged in' do
        process :options, 'OPTIONS'
        @service_profile = 'http://iiif.io/api/image/2/auth/login'
        check_service
      end
      it 'returns logout information, while a user is logged in' do
        login
        process :options, 'OPTIONS'
        @service_profile = 'http://iiif.io/api/image/2/auth/logout'
        check_service
      end
      it 'does not respond to GET' do
        process :options, 'GET'
        expect(response.status).to eq(405)
        err = JSON.parse(response.body)
        expect(err).not_to be_empty
        expect(err['error']).to eql('invalidRequest')
        expect(err['errorDescription']).to include('OPTIONS')
      end
    end
  end

  describe 'POST /auth/login' do
    before :each do
      set_json_headers
    end
    let(:auth_code_params) {
      {code: auth_code }
    }
    it 'rejects a request that has no "userId" field (response code 401)' do
      data = login_credentials.except 'userId'
      post :login, data.to_json, auth_code_params
      login_credentials_required
    end
    it 'rejects a request that has no "workgroups" field (response code 401)' do
      data = login_credentials.except 'workgroups'
      post :login, data.to_json, auth_code_params
      login_credentials_required
    end
    it 'requires an authorization code (response code 401)' do
      post :login, login_credentials.to_json
      expect(response.status).to eql(401)
      err = JSON.parse(response.body)
      expect(err).not_to be_empty
      expect(err['error']).to eql('invalidClient')
      expect(err['errorDescription']).to eql('authorization code is required')
    end
    it 'rejects an invalid authorization code (response code 403)' do
      auth_code # first the client requests a code (setup session data)
      params = {code: 'invalid_auth_code' } # invalid code != session data
      post :login, login_credentials.to_json, params
      expect(response.status).to eql(403)
      err = JSON.parse(response.body)
      expect(err).not_to be_empty
      expect(err['error']).to eql('invalidClient')
      expect(err['errorDescription']).to eql('Unable to validate authorization code')
    end
    it 'accepts login data from authorized client (response code 302)' do
      data = {userId: 'userAnon', workgroups: 'doh :-)'}
      post :login, data.to_json, auth_code_params
      expect(response.status).to eql(302)
    end
    it 'excludes extraneous data from login data' do
      data = {userId: 'userAnon', workgroups: 'doh :-)', extraneous: 'xyz'}
      post :login, data.to_json, auth_code_params
      expect(response.status).to eql(302)
      data = session['login_data']
      expect(data.keys).not_to include('extraneous')
    end
    it 'accepts "workgroups" values as Array' do
      data = login_credentials
      expect(data['workgroups']).to be_instance_of Array
      post :login, data.to_json, auth_code_params
      expect(response.status).to eql(302)
      wg = session['login_data']['workgroups']
      expect(wg).to be_instance_of Array
      expect(wg).not_to be_empty
    end
    it 'accepts "workgroups" values as CSV String' do
      data = login_credentials
      data['workgroups'] = 'org:wg-A, org:wg-B' # will be split(',')
      expect(data['workgroups']).to be_instance_of String
      post :login, data.to_json, auth_code_params
      expect(response.status).to eql(302)
      wg = session['login_data']['workgroups']
      expect(wg).to be_instance_of Array
      expect(wg).not_to be_empty
    end
    it 'rejects "workgroups" values as nil' do
      data = login_credentials
      data['workgroups'] = nil # not acceptable
      expect(data['workgroups']).to be_nil
      post :login, data.to_json, auth_code_params
      expect(response.status).to eql(401)
      expect(session['login_data']).to be_nil
    end
    it 'rejects "userId" values as nil' do
      data = login_credentials
      data['userId'] = nil # not acceptable
      expect(data['userId']).to be_nil
      post :login, data.to_json, auth_code_params
      expect(response.status).to eql(401)
      expect(session['login_data']).to be_nil
    end
    it 'rejects data values that are not JSON compatible' do
      # e.g. Some SecureRandom.random_bytes are not acceptable
      data = login_credentials
      data['userId'] = 'REPLACE'
      json = data.to_json.gsub('REPLACE', "R\x13\n\xC3\xD8")
      post :login, json, auth_code_params
      expect(response.status).to eql(422)
      expect(session['login_data']).to be_nil
    end
    it 'does not respond to GET' do
      process :login, 'GET'
      expect(response.status).to eq(405)
      err = JSON.parse(response.body)
      expect(err).not_to be_empty
      expect(err['error']).to eql('invalidRequest')
      expect(err['errorDescription']).to include('POST')
    end
    it 'rejects HTML content' do
      data = {userId: 'userA', workgroups: 'wgA'}
      params = {code: auth_code}
      request.headers['Content-Type'] = 'text/html'
      post :login, data.to_json, params
      expect(response.status).to eql(415)
    end
  end

  describe 'GET /auth/logout' do
    it 'response status is 302 and redirects to root path' do
      get :logout
      expect(response.status).to eq(302)
      expect(response).to redirect_to('/')
    end
    it 'clears login cookie' do
      login
      expect(response.cookies['login_user']).not_to be_nil
      request.cookies['login_user'] = response.cookies[:login_user]
      get :logout
      expect(response.cookies['login_user']).to be_nil
    end
    it 'resets session' do
      # Note that this seems to be tricky to test, e.g.
      # http://stackoverflow.com/questions/20912954/rspec-and-reset-session-do-not-work-together
      # In this test, the login/logout notices are different, and that will suffice; although
      # it would be ideal to test for different session IDs, they are not different because
      # the test apparatus uses the same session across get calls in this example.
      login
      login_session = session.dup
      login_notice = flash.notice
      expect(login_session).not_to be_nil
      expect(login_notice).not_to be_nil
      get :logout
      logout_session = session.dup
      logout_notice = flash.notice
      expect(logout_session).not_to be_nil
      expect(logout_session).not_to eql(login_session)
      expect(logout_notice).not_to be_nil
      expect(logout_notice).not_to eql(login_notice)
    end
    it 'does not respond to OPTIONS' do
      set_json_headers
      process :logout, 'OPTIONS'
      expect(response.status).to eq(405)
      err = JSON.parse(response.body)
      expect(err).not_to be_empty
      expect(err['error']).to eql('invalidRequest')
      expect(err['errorDescription']).to include('GET')
    end
  end # /auth/logout


  describe 'POST /auth/client_identity' do
    before :each do
      set_json_headers
    end
    let(:client_credentials_required) {
      expect(response.status).to eql(401)
      err = JSON.parse(response.body)
      expect(err).not_to be_empty
      expect(err['error']).to eql('invalidClient')
      err
    }
    it 'accepts JSON content' do
      post :client_identity, client_credentials.to_json
      expect(response.status).to eql(200)
    end
    it 'rejects HTML content' do
      request.headers['Content-Type'] = 'text/html'
      post :client_identity, client_credentials.to_json
      expect(response.status).to eql(415)
    end
    it 'rejects a request without "clientId" (response code 401)' do
      data = client_credentials.except 'clientId'
      post :client_identity, data.to_json
      err = client_credentials_required
      expect(err['errorDescription']).to eql('Insufficient client data for authentication')
    end
    it 'rejects a request without "clientSecret" (response code 401)' do
      data = client_credentials.except 'clientSecret'
      post :client_identity, data.to_json
      err = client_credentials_required
      expect(err['errorDescription']).to eql('Insufficient client data for authentication')
    end
    it 'rejects unauthorized client requests (response code 401)' do
      data = {clientId: 'clientA', clientSecret: 'secretB'}
      post :client_identity, data.to_json
      err = client_credentials_required
      expect(err['errorDescription']).to eql('Invalid client credentials')
    end
    it 'returns an authorizationCode for authorized clients (response code 200)' do
      post :client_identity, client_credentials.to_json
      expect(response.status).to eql(200)
      data = JSON.parse(response.body)
      expect(data).not_to be_empty
      expect(data['authorizationCode']).not_to be_nil
      expect(data['authorizationCode']).to be_instance_of String
    end
  end # /auth/client_identity


  # adapted from
  # http://image-auth.iiif.io/api/image/2.1/authentication.html#access-token-service
  describe 'GET /auth/access_token' do
    let(:token_data) {
      expect(response.cookies['login_user']).to be_nil
      data = JSON.parse(response.body)
      expect(data).not_to be_empty
      data
    }
    before :each do
      set_json_headers
    end
    describe 'with valid login credentials' do
      before :each do
        login
      end
      it 'with a valid authorization code - returns an access code' do
        get :access_token, code: auth_code
        expect(response.status).to eql(200)
        expect(token_data['accessToken']).not_to be_nil
        expect(token_data['accessToken']).to be_instance_of String
      end
      it 'with an invalid authorization code - response status is 403' do
        get :access_token, code: 'invalid_auth_code'
        expect(response.status).to eq(403)
        expect(token_data['error']).to eql('invalidClient')
        expect(token_data['errorDescription']).to eql('Unable to validate authorization code')
      end
      it 'without an authorization code - response status is 401' do
        get :access_token
        expect(response.status).to eq(401)
        expect(token_data['error']).to eql('invalidClient')
        expect(token_data['errorDescription']).to eql('authorization code is required')
      end
    end

    describe 'without valid login -' do
      it 'with a valid authorization code - response status is 401' do
        get :access_token, code: auth_code
        login_credentials_required
      end
      it 'without an authorization code - response status is 401' do
        get :access_token
        login_credentials_required
      end
    end
  end # /auth/access_token

  describe 'GET /auth/access_validate -' do
    it 'response code is 200 for a valid access token' do
      request.headers['Authorization'] = "Bearer #{access_token}"
      get :access_validate
      expect(response.status).to eq(200)
    end
    it 'access token is not sufficient, login session is required' do
      token = access_token
      get :logout # resets session data, required to validate token
      request.headers['Authorization'] = "Bearer #{token}"
      get :access_validate
      expect(response.status).to eq(401)
    end
    it 'response code is 401 with invalid access token' do
      request.headers['Authorization'] = "Bearer invalid_token"
      get :access_validate
      expect(response.status).to eq(401)
    end
    it 'response code is 401 with no access token' do
      request.headers['Authorization'] = nil
      get :access_validate
      expect(response.status).to eq(401)
    end
    it 'response code is 401 without "Bearer" authorization' do
      request.headers['Authorization'] = "Digest #{access_token}"
      get :access_validate
      expect(response.status).to eq(401)
    end
  end # /auth/access_validate

  # ApplicationController#access_token_data should be available to
  # any controllers; it is tested here in the context of authentication.
  describe '#access_token_data' do
    it 'returns nil for no Authorization header' do
      access_data = subject.send(:access_token_data, {})
      expect(access_data).to be_nil
    end
    it 'returns nil for Authorization header without "Bearer"' do
      headers = {'Authorization' => 'Basic invalid_data'}
      access_data = subject.send(:access_token_data, headers)
      expect(access_data).to be_nil
    end
    it 'returns nil for invalid access token' do
      headers = {'Authorization' => "Bearer invalid_data"}
      access_data = subject.send(:access_token_data, headers)
      expect(access_data).to be_nil
    end
    it 'returns login data for valid access token' do
      headers = {'Authorization' => "Bearer #{access_token}"}
      access_data = subject.send(:access_token_data, headers)
      expect(access_data).to eql(login_credentials)
    end
  end #ApplicationController#access_token_data

  # ApplicationController#authorize should be available to
  # any controllers; it is tested here in the context of authentication.
  describe '#authorize' do
    it 'is called for any request' do
      expect(controller).to receive(:authorize).twice
      expect(controller).not_to receive(:authorized_workgroup?)
      process :options, 'OPTIONS'
      expect(response.status).to eql(200)
      get :logout
      expect(response.status).to eql(302)
    end
    it 'allows any GET request' do
      expect(controller).to receive(:authorize).once
      expect(controller).not_to receive(:authorized_workgroup?)
      get :logout
    end
    it 'allows POST requests to an /auth path' do
      expect(controller).to receive(:authorize).once
      expect(controller).not_to receive(:authorized_workgroup?)
      set_json_headers
      post :client_identity, client_credentials.to_json
      expect(response.status).to eql(200)
    end
    it 'allows DELETE requests to an /auth path' do
      expect(controller).to receive(:authorize).once
      expect(controller).not_to receive(:authorized_workgroup?)
      set_json_headers
      delete :client_identity, client_credentials.to_json
      expect(response.status).to eql(405) # DELETE is not handled
      expect(response.headers['Allow']).to eql('POST')
    end
  end #ApplicationController#authorize


end
