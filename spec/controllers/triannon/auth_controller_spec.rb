require 'spec_helper'

describe Triannon::AuthController, :vcr, type: :controller do

  routes { Triannon::Engine.routes }

  before :all do
    Triannon.config[:authorized_clients] = {'clientA'=>'secretA'}
    Triannon.config[:authorized_users] = {'userA'=>'secretA'}
  end

  let(:accept_json) {
    request.headers['Accept'] = 'application/json'
  }
  let(:content_json) {
    request.headers['Content-Type'] =  'application/json'
  }

  describe '/auth/login' do
    describe 'responds to GET and OPTIONS requests' do
      it 'GET has a route to /auth/login' do
        expect(:get => '/auth/login').to be_routable
      end
      it 'OPTIONS has a route to /auth/login' do
        expect(:options => '/auth/login').to be_routable
      end
      it 'DELETE has no route to /auth/login' do
        expect(:delete => '/auth/login').not_to be_routable
      end
      it 'POST has no route to /auth/login' do
        expect(:post => '/auth/login').not_to be_routable
      end
      it 'PUT has no route to /auth/login' do
        expect(:put => '/auth/login').not_to be_routable
      end
    end
    describe 'OPTIONS requests for /auth/login:' do
      it 'reject GET requests for information' do
        process :options, 'GET'
        expect(response.status).to eq(405)
      end
      context 'when JSON is accepted:' do
        it 'returns logout information while a user is logged in' do
          basic_auth('userA', 'secretA')
          get :login
          accept_json
          process :options, 'OPTIONS'
          json = JSON.parse(response.body)
          expect(json.keys).to eql(['service'])
          info = json['service']
          expect(info.keys).to eql(['@id','profile', 'label'])
          expect(info['profile']).to eql('http://iiif.io/api/image/2/auth/logout')
        end
        it 'returns login information with no user logged in' do
          get :logout
          accept_json
          process :options, 'OPTIONS'
          json = JSON.parse(response.body)
          expect(json.keys).to eql(['service'])
          info = json['service']
          expect(info.keys).to eql(['@id','profile', 'label'])
          expect(info['profile']).to eql('http://iiif.io/api/image/2/auth/login')
        end
      end
    end
    describe 'rejects unauthorized login' do
      let(:check_unauthorized) do
        get :login
        expect(response.status).to eq(401)
      end
      context 'HTML' do
        it 'GET response status is 401 for anonymous user' do
          check_unauthorized
        end
        it 'GET response status is 401 for unauthorized user' do
          # curl -v -u fred:bloggs http://localhost:3000/auth/login
          basic_auth('guessed', 'wrong')
          check_unauthorized
        end
        it 'GET does not set a login cookie for unauthorized user' do
          basic_auth('guessed', 'wrong')
          check_unauthorized
          expect(response.cookies['login_user']).to be_nil
        end
        it 'GET response status is 401 for invalid password on authorized user' do
          # curl -v -u userA:secretB http://localhost:3000/auth/login
          basic_auth('userA', 'wrong')
          check_unauthorized
        end
        it 'GET response status is 401 for correct password on unauthorized user' do
          basic_auth('userB', 'secretA')
          check_unauthorized
        end
      end
      context 'JSON' do
        before :each do
          accept_json
        end
        let(:unauthorized_json_response) do
          check_unauthorized
          json = JSON.parse(response.body)
          expect(json.keys).to eql(["error", "errorDescription", "errorUri"])
        end
        it 'GET response status is 401 for anonymous user' do
          # curl -v -H "Accept: application/json" http://localhost:3000/auth/login
          unauthorized_json_response
        end
        it 'GET response status is 401 for unauthorized user' do
          # curl -v -u fred:bloggs -H "Accept: application/json" http://localhost:3000/auth/login
          # {"error":"401 Unauthorized","errorDescription":"invalid login details received","errorUri":"http://image-auth.iiif.io/api/image/2.1/authentication.html"}
          basic_auth('guessed', 'wrong')
          unauthorized_json_response
        end
        it 'GET does not set a login cookie for unauthorized user' do
          basic_auth('guessed', 'wrong')
          unauthorized_json_response
          expect(response.cookies['login_user']).to be_nil
        end
        it 'GET response status is 401 for invalid password on authorized user' do
          # curl -v -u userA:secretB  -H "Accept: application/json" http://localhost:3000/auth/login
          basic_auth('userA', 'wrong')
          unauthorized_json_response
        end
        it 'GET response status is 401 for valid password on unauthorized user' do
          # curl -v -u userA:secretB  -H "Accept: application/json" http://localhost:3000/auth/login
          basic_auth('userB', 'secretA')
          unauthorized_json_response
        end
      end
    end
    describe 'accepts authorized login' do
      # curl -v -u userA:secretA http://localhost:3000/auth/login
      before :each do
        basic_auth('userA', 'secretA')
      end
      let(:authorized_response) do
        get :login
        expect(response.status).to eq(302)
        expect(response).to redirect_to('/')
      end
      it 'GET response status is 302 and redirects to root for authorized user' do
        authorized_response
      end
      it 'GET sets a login cookie for authorized user' do
        authorized_response
        expect(response.cookies['login_user']).not_to be_nil
      end
      context 'JSON' do
        # curl -u userA:secretA  -H "Accept: application/json" http://localhost:3000/auth/login
        before :each do
          accept_json
        end
        it 'GET does not return a json document for authorized user' do
          authorized_response
          expect(response.cookies['login_user']).not_to be_nil
          expect{ JSON.parse(response.body) }.to raise_error
        end
      end
    end
  end # /auth/login

  describe 'GET /auth/logout' do
    describe 'only responds to GET requests' do
      it 'GET has a route to /auth/logout' do
        expect(:get => '/auth/logout').to be_routable
      end
      it 'DELETE has no route to /auth/logout' do
        expect(:delete => '/auth/logout').not_to be_routable
      end
      it 'OPTIONS has no route to /auth/logout' do
        expect(:options => '/auth/logout').not_to be_routable
      end
      it 'POST has no route to /auth/logout' do
        expect(:post => '/auth/logout').not_to be_routable
      end
      it 'PUT has no route to /auth/logout' do
        expect(:put => '/auth/logout').not_to be_routable
      end
    end
    it 'GET response status is 302 and redirects to root path' do
      get :logout
      expect(response.status).to eq(302)
      expect(response).to redirect_to('/')
    end
    it 'clears login cookie' do
      basic_auth('userA', 'secretA')
      get :login
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
      basic_auth('userA', 'secretA')
      get :login
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
      basic_auth('userA', 'secretA')
    end
    describe 'only responds to POST requests' do
      it 'POST has a route to /auth/client_identity' do
        expect(:post => '/auth/client_identity').to be_routable
      end
      it 'DELETE has no route to /auth/client_identity' do
        expect(:delete => '/auth/client_identity').not_to be_routable
      end
      it 'GET has no route to /auth/client_identity' do
        expect(:get => '/auth/client_identity').not_to be_routable
      end
      it 'OPTIONS has no route to /auth/client_identity' do
        expect(:options => '/auth/client_identity').not_to be_routable
      end
      it 'PUT has no route to /auth/client_identity' do
        expect(:put => '/auth/client_identity').not_to be_routable
      end
    end
    it 'accepts JSON content' do
      accept_json
      content_json
      params = {clientId: 'clientA', clientSecret: 'secretA'}
      post :client_identity, params.to_json
      expect(response.code.to_i).to eql(200)
    end
    it 'rejects HTML content' do
      request.headers['Content-Type'] = 'text/html'
      params = {clientId: 'clientA', clientSecret: 'secretA'}
      post :client_identity, params.to_json
      expect(response.code.to_i).to eql(415)
    end
    # The request MUST carry a body with the following JSON template:
    # {
    #   "clientId" : "CLIENT_ID_HERE",
    #   "clientSecret" : "CLIENT_SECRET_HERE"
    # }
    it 'rejects a request that has no "clientId" field (response code 400)' do
      accept_json
      content_json
      params = {clientSecret: 'secretA'}
      post :client_identity, params.to_json
      expect(response.code.to_i).to eql(400)
      err = JSON.parse(response.body)
      expect(err).not_to be_empty
      expect(err['errorDescription']).to match(/requires.*clientId/)
    end
    it 'rejects a request that has no "clientSecret" field (response code 400)' do
      accept_json
      content_json
      params = {clientId: 'clientA'}
      post :client_identity, params.to_json
      expect(response.code.to_i).to eql(400)
      err = JSON.parse(response.body)
      expect(err).not_to be_empty
      expect(err['errorDescription']).to match(/requires.*clientSecret/)
    end
    it 'rejects unauthorized client requests (response code 401)' do
      accept_json
      content_json
      params = {clientId: 'clientA', clientSecret: 'secretB'}
      post :client_identity, params.to_json
      expect(response.code.to_i).to eql(401)
      err = JSON.parse(response.body)
      expect(err).not_to be_empty
      expect(err['error']).to eql('invalidClient')
    end
    it 'returns an authorizationCode for authorized clients (response code 200)' do
      accept_json
      content_json
      params = {clientId: 'clientA', clientSecret: 'secretA'}
      post :client_identity, params.to_json
      expect(response.code.to_i).to eql(200)
      data = JSON.parse(response.body)
      expect(data).not_to be_empty
      expect(data['authorizationCode']).not_to be_nil
      expect(data['authorizationCode']).to be_instance_of String
    end
  end # /auth/client_identity

  # adapted from
  # http://image-auth.iiif.io/api/image/2.1/authentication.html#access-token-service
  describe 'GET /auth/access_token' do
    let(:login) {
      basic_auth('userA', 'secretA')
      get :login
      expect(response.status).to eq(302)
      expect(response).to redirect_to('/')
      expect(response.cookies['login_user']).not_to be_nil
    }
    let(:get_auth_code) {
      accept_json
      content_json
      params = {clientId: 'clientA', clientSecret: 'secretA'}
      post :client_identity, params.to_json
      expect(response.code.to_i).to eql(200)
      data = JSON.parse(response.body)
      expect(data).not_to be_empty
      expect(data['authorizationCode']).not_to be_nil
      expect(data['authorizationCode']).to be_instance_of String
      data['authorizationCode']
    }
    let(:check_access_token) {
      expect(response.code.to_i).to eql(200)
      expect(response.cookies['login_user']).to be_nil
      data = JSON.parse(response.body)
      expect(data).not_to be_empty
      expect(data['accessToken']).not_to be_nil
      expect(data['accessToken']).to be_instance_of String
    }
    describe 'only responds to GET requests' do
      it 'GET has a route to /auth/access_token' do
        expect(:get => '/auth/access_token').to be_routable
      end
      it 'DELETE has no route to /auth/access_token' do
        expect(:delete => '/auth/access_token').not_to be_routable
      end
      it 'OPTIONS has no route to /auth/access_token' do
        expect(:options => '/auth/access_token').not_to be_routable
      end
      it 'POST has no route to /auth/access_token' do
        expect(:post => '/auth/access_token').not_to be_routable
      end
      it 'PUT has no route to /auth/access_token' do
        expect(:put => '/auth/access_token').not_to be_routable
      end
    end
    describe 'with valid login credentials' do
      before :each do
        login
      end
      it 'returns an access code, given a valid authorization code' do
        code = get_auth_code
        get :access_token, {code: code}
        check_access_token
      end
      it 'returns an access code, without any authorization code' do
        accept_json
        content_json
        get :access_token
        check_access_token
      end
    end
    describe 'without valid login credentials' do
      it 'returns an access code, given a valid authorization code' do
        code = get_auth_code
        get :access_token, {code: code}
        check_access_token
      end
      # it 'returns an error, without any authorization code' do
      it 'redirects to /auth/login, without any authorization code' do
        accept_json
        content_json
        get :access_token
        expect(response.status).to eq(302)
        expect(response).to redirect_to('/auth/login')
        expect(response.cookies['login_user']).to be_nil
      end
    end
  end # /auth/access_token


  protected

  def basic_auth(user, pass)
    # request.env['HTTP_AUTHORIZATION'] = basic_auth_code(user, pass)
    request.headers['Authorization'] = basic_auth_code(user, pass)
  end

  def basic_auth_code(user, pass)
    ActionController::HttpAuthentication::Basic.encode_credentials(user, pass)
  end

end