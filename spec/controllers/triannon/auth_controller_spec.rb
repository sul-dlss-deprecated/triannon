require 'spec_helper'

describe Triannon::AuthController, :vcr, type: :controller do

  routes { Triannon::Engine.routes }

  before :all do
    Triannon.config[:authorized_clients] = {'clientA'=>'secretA'}
    Triannon.config[:client_token_expiry] = 60
    Triannon.config[:access_token_expiry] = 3600
  end

  let(:accept_json) {
    request.headers['Accept'] = 'application/json'
  }
  let(:content_json) {
    request.headers['Content-Type'] =  'application/json'
  }
  let(:json_payloads) {
    accept_json
    content_json
  }
  let(:access_token) {
    login
    get :access_token, code: auth_code
    data = JSON.parse(response.body)
    data['accessToken']
  }
  let(:auth_code) {
    json_payloads
    data = {clientId: 'clientA', clientSecret: 'secretA'}
    post :client_identity, data.to_json
    expect(response.status).to eql(200)
    data = JSON.parse(response.body)
    data['authorizationCode']
  }
  let(:login) {
    json_payloads
    data = {userId: 'userA', userSecret: 'secretA'}
    post :login, data.to_json, code: auth_code
    expect(response.status).to eq(302)
    expect(response).to redirect_to('/')
    expect(response.cookies['login_user']).not_to be_nil
  }

  describe 'OPTIONS /auth/login' do
    let(:check_service) {
      json = JSON.parse(response.body)
      expect(json.keys).to eql(['service'])
      info = json['service']
      expect(info.keys).to eql(['@id','profile', 'label'])
      expect(info['profile']).to eql(@service_profile)
    }
    context 'accept JSON:' do
      it 'returns login information, with no user logged in' do
        accept_json
        process :options, 'OPTIONS'
        @service_profile = 'http://iiif.io/api/image/2/auth/login'
        check_service
      end
      it 'returns logout information, while a user is logged in' do
        login
        accept_json
        process :options, 'OPTIONS'
        @service_profile = 'http://iiif.io/api/image/2/auth/logout'
        check_service
      end
    end
  end

  describe 'POST /auth/login' do
    before :each do
      json_payloads
    end
    it 'rejects HTML content' do
      data = {userId: 'userA', userSecret: 'secretA'}
      params = {code: auth_code }
      request.headers['Content-Type'] = 'text/html'
      post :login, data.to_json, params
      expect(response.status).to eql(415)
    end
    it 'rejects a request that has no "userId" field (response code 401)' do
      data = {userSecret: 'secretA'}
      params = {code: auth_code }
      post :login, data.to_json, params
      expect(response.status).to eql(401)
      err = JSON.parse(response.body)
      expect(err).not_to be_empty
      expect(err['errorDescription']).to eql('login credentials required')
    end
    it 'rejects a request that has no "userSecret" field (response code 401)' do
      data = {userId: 'userA'}
      params = {code: auth_code }
      post :login, data.to_json, params
      expect(response.status).to eql(401)
      err = JSON.parse(response.body)
      expect(err).not_to be_empty
      expect(err['errorDescription']).to eql('login credentials required')
    end
    it 'accepts any user login data from authorized client (response code 302)' do
      data = {userId: 'userAnon', userSecret: 'whatever'}
      params = {code: auth_code }
      post :login, data.to_json, params
      expect(response.status).to eql(302)
    end
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
  end # /auth/logout


  describe 'POST /auth/client_identity' do
    before :each do
      accept_json
      content_json
    end
    it 'accepts JSON content' do
      params = {clientId: 'clientA', clientSecret: 'secretA'}
      post :client_identity, params.to_json
      expect(response.status).to eql(200)
    end
    it 'rejects HTML content' do
      request.headers['Content-Type'] = 'text/html'
      params = {clientId: 'clientA', clientSecret: 'secretA'}
      post :client_identity, params.to_json
      expect(response.status).to eql(415)
    end
    it 'rejects a request without "clientId" (response code 401)' do
      data = {clientSecret: 'secretA'}
      post :client_identity, data.to_json
      expect(response.status).to eql(401)
      err = JSON.parse(response.body)
      expect(err).not_to be_empty
      expect(err['error']).to eql('invalidClient')
      expect(err['errorDescription']).to eql('Insufficient client data for authentication')
    end
    it 'rejects a request without "clientSecret" (response code 401)' do
      data = {clientId: 'clientA'}
      post :client_identity, data.to_json
      expect(response.status).to eql(401)
      err = JSON.parse(response.body)
      expect(err).not_to be_empty
      expect(err['error']).to eql('invalidClient')
      expect(err['errorDescription']).to eql('Insufficient client data for authentication')
    end
    it 'rejects unauthorized client requests (response code 403)' do
      data = {clientId: 'clientA', clientSecret: 'secretB'}
      post :client_identity, data.to_json
      expect(response.status).to eql(403)
      err = JSON.parse(response.body)
      expect(err).not_to be_empty
      expect(err['error']).to eql('invalidClient')
      expect(err['errorDescription']).to eql('Invalid client credentials')
    end
    it 'returns an authorizationCode for authorized clients (response code 200)' do
      data = {clientId: 'clientA', clientSecret: 'secretA'}
      post :client_identity, data.to_json
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
    describe 'with valid login credentials' do
      before :each do
        login
      end
      it 'returns an access code, given a valid authorization code' do
        get :access_token, code: auth_code
        expect(response.status).to eql(200)
        expect(response.cookies['login_user']).to be_nil
        data = JSON.parse(response.body)
        expect(data).not_to be_empty
        expect(data['accessToken']).not_to be_nil
        expect(data['accessToken']).to be_instance_of String
      end
      it 'response status is 401, without an authorization code' do
        get :access_token
        expect(response.status).to eq(401)
        expect(response.cookies['login_user']).to be_nil
        err = JSON.parse(response.body)
        expect(err).not_to be_empty
        expect(err['error']).to eql('invalidClient')
        expect(err['errorDescription']).to eql('authorization code is required')
      end
    end

    describe 'without valid login credentials' do
      it 'response status is 401, with a valid authorization code' do
        accept_json
        get :access_token, code: auth_code
        expect(response.status).to eq(401)
        expect(response.cookies['login_user']).to be_nil
        err = JSON.parse(response.body)
        expect(err).not_to be_empty
        expect(err['errorDescription']).to eql('login credentials required')
      end
      it 'response status is 401, without an authorization code' do
        accept_json
        get :access_token
        expect(response.status).to eq(401)
        expect(response.cookies['login_user']).to be_nil
        err = JSON.parse(response.body)
        expect(err).not_to be_empty
        expect(err['errorDescription']).to eql('login credentials required')
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
      expect(response.status).to eq(403)
    end
    it 'response code is 403 with invalid access token' do
      request.headers['Authorization'] = "Bearer invalid_token"
      get :access_validate
      expect(response.status).to eq(403)
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

end
