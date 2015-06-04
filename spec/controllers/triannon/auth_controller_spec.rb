require 'spec_helper'

describe Triannon::AuthController, :vcr, type: :controller do

  routes { Triannon::Engine.routes }

  before :all do
    Triannon.config[:authorized_clients] = {'clientA'=>'secretA'}
    Triannon.config[:authorized_users] = {'userA'=>'secretA'}
  end

  describe '/auth/login' do

    describe 'only responds to GET requests' do
      it 'GET has a route to /auth/login' do
        expect(:get => '/auth/login').to be_routable
      end
      it 'DELETE has no route to /auth/login' do
        expect(:delete => '/auth/login').not_to be_routable
      end
      it 'OPTIONS has no route to /auth/login' do
        expect(:options => '/auth/login').not_to be_routable
      end
      it 'POST has no route to /auth/login' do
        expect(:post => '/auth/login').not_to be_routable
      end
      it 'PUT has no route to /auth/login' do
        expect(:put => '/auth/login').not_to be_routable
      end
    end

    describe 'rejects unauthorized login' do
      let(:check_unauthorized) do
        get :login
        expect(response.status).to eq(401)
      end
      context 'HTML' do
        it 'GET responds with 401 for anonymous user' do
          check_unauthorized
        end
        it 'GET responds with 401 for unauthorized user' do
          # curl -v -u fred:bloggs http://localhost:3000/auth/login
          # curl -v -u fred:bloggs -H "Accept: application/json" http://localhost:3000/auth/login
          # {"error":"401 Unauthorized","errorDescription":"invalid login details received","errorUri":"http://image-auth.iiif.io/api/image/2.1/authentication.html"}
          request.env['HTTP_AUTHORIZATION'] = basic_auth_code('guessed', 'wrong')
          check_unauthorized
        end
        it 'GET does not set a login cookie for unauthorized user' do
          request.env['HTTP_AUTHORIZATION'] = basic_auth_code('guessed', 'wrong')
          check_unauthorized
          expect(response.cookies['login_user']).to be_nil
        end
        it 'GET responds with 401 for invalid password on authorized user' do
          # curl -v -u userA:secretB  -H "Accept: application/json" http://localhost:3000/auth/login
          # curl -v -u userA:secretB http://localhost:3000/auth/login
          request.env['HTTP_AUTHORIZATION'] = basic_auth_code('userA', 'wrong')
          check_unauthorized
        end
      end
      context 'JSON' do
        before :each do
          request.env['HTTP_ACCEPT'] = 'application/json'
        end
        let(:unauthorized_json_response) do
          check_unauthorized
          json = JSON.parse(response.body)
          expect(json.keys).to eql(["error", "errorDescription", "errorUri"])
        end
        it 'GET responds with 401 for anonymous user' do
          # curl -v -H "Accept: application/json" http://localhost:3000/auth/login
          unauthorized_json_response
        end
        it 'GET responds with 401 for unauthorized user' do
          # curl -v -u fred:bloggs -H "Accept: application/json" http://localhost:3000/auth/login
          # {"error":"401 Unauthorized","errorDescription":"invalid login details received","errorUri":"http://image-auth.iiif.io/api/image/2.1/authentication.html"}
          request.env['HTTP_AUTHORIZATION'] = basic_auth_code('guessed', 'wrong')
          unauthorized_json_response
        end
        it 'GET does not set a login cookie for unauthorized user' do
          request.env['HTTP_AUTHORIZATION'] = basic_auth_code('guessed', 'wrong')
          unauthorized_json_response
          expect(response.cookies['login_user']).to be_nil
        end
        it 'GET responds with 401 for invalid password on authorized user' do
          # curl -v -u userA:secretB  -H "Accept: application/json" http://localhost:3000/auth/login
          request.env['HTTP_AUTHORIZATION'] = basic_auth_code('userA', 'wrong')
          unauthorized_json_response
        end
      end
    end

    it 'GET responds with 302 and redirect to root for authorized user' do
      # curl -v -u userA:secretA http://localhost:3000/auth/login
      request.env['HTTP_AUTHORIZATION'] = basic_auth_code('userA', 'secretA')
      get :login
      expect(response.status).to eq(302)
      expect(response).to redirect_to('/')
    end
    it 'GET sets a login cookie for authorized user' do
      # curl -v -u userA:secretA http://localhost:3000/auth/login
      request.env['HTTP_AUTHORIZATION'] = basic_auth_code('userA', 'secretA')
      get :login
      expect(response.status).to eq(302)
      expect(response).to redirect_to('/')
      expect(response.cookies['login_user']).not_to be_nil
    end
    it 'GET returns json document for authorized user with json accept header'
    # curl -u userA:secretA  -H "Accept: application/json" http://localhost:3000/auth/login
  end



  describe '#logout' do
    it 'GET has a route to /auth/logout' do
      expect(:get => '/auth/logout').to be_routable
    end
    it 'clears client cookie'
    it 'resets session'
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

  describe 'POST /auth/client_identity' do
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


  protected

  def basic_auth_code(user, pass)
    ActionController::HttpAuthentication::Basic.encode_credentials(user, pass)
  end

  def debug
    eval('require "pry"; binding.pry')
  end



end
