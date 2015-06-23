require 'spec_helper'

describe Triannon::AuthController, type: :routing do

  routes { Triannon::Engine.routes }

  describe '/auth/login' do
    describe 'responds to GET and OPTIONS requests' do
      it 'GET has a route to /auth/login' do
        expect(:get => '/auth/login').to be_routable
      end
      it 'GET /auth/login routes to triannon/auth#login' do
        expect(:get => '/auth/login').to route_to(
          controller: 'triannon/auth',
          action: 'login')
      end
      it 'OPTIONS has a route to /auth/login' do
        expect(:options => '/auth/login').to be_routable
      end
      it 'OPTIONS /auth/login routes to triannon/auth#options' do
        expect(:options => '/auth/login').to route_to(
          controller: 'triannon/auth',
          action: 'options')
      end
      it 'DELETE has no route to /auth/login' do
        expect(:delete => '/auth/login').not_to be_routable
      end
      it 'PATCH has no route to /auth/login' do
        expect(:patch => '/auth/login').not_to be_routable
      end
      it 'POST has no route to /auth/login' do
        expect(:post => '/auth/login').not_to be_routable
      end
      it 'PUT has no route to /auth/login' do
        expect(:put => '/auth/login').not_to be_routable
      end
    end
  end # /auth/login

  describe 'GET /auth/logout' do
    describe 'only responds to GET requests' do
      it 'GET has a route to /auth/logout' do
        expect(:get => '/auth/logout').to be_routable
      end
      it 'GET /auth/logout routes to triannon/auth#logout' do
        expect(:get => '/auth/logout').to route_to(
          controller: 'triannon/auth',
          action: 'logout')
      end
      it 'DELETE has no route to /auth/logout' do
        expect(:delete => '/auth/logout').not_to be_routable
      end
      it 'OPTIONS has no route to /auth/logout' do
        expect(:options => '/auth/logout').not_to be_routable
      end
      it 'PATCH has no route to /auth/logout' do
        expect(:patch => '/auth/logout').not_to be_routable
      end
      it 'POST has no route to /auth/logout' do
        expect(:post => '/auth/logout').not_to be_routable
      end
      it 'PUT has no route to /auth/logout' do
        expect(:put => '/auth/logout').not_to be_routable
      end
    end
  end # /auth/logout

  describe 'POST /auth/client_identity' do
    describe 'only responds to POST requests' do
      it 'POST has a route to /auth/client_identity' do
        expect(:post => '/auth/client_identity').to be_routable
      end
      it 'POST /auth/client_identity routes to triannon/auth#client_identity' do
        expect(:post => '/auth/client_identity').to route_to(
          controller: 'triannon/auth',
          action: 'client_identity')
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
      it 'PATCH has no route to /auth/client_identity' do
        expect(:patch => '/auth/client_identity').not_to be_routable
      end
      it 'PUT has no route to /auth/client_identity' do
        expect(:put => '/auth/client_identity').not_to be_routable
      end
    end
  end # /auth/client_identity

  describe 'GET /auth/access_token' do
    describe 'only responds to GET requests' do
      it 'GET has a route to /auth/access_token' do
        expect(:get => '/auth/access_token').to be_routable
      end
      it 'GET /auth/access_token routes to triannon/auth#access_token' do
        expect(:get => '/auth/access_token').to route_to(
          controller: 'triannon/auth',
          action: 'access_token')
      end
      it 'DELETE has no route to /auth/access_token' do
        expect(:delete => '/auth/access_token').not_to be_routable
      end
      it 'OPTIONS has no route to /auth/access_token' do
        expect(:options => '/auth/access_token').not_to be_routable
      end
      it 'PATCH has no route to /auth/access_token' do
        expect(:patch => '/auth/access_token').not_to be_routable
      end
      it 'POST has no route to /auth/access_token' do
        expect(:post => '/auth/access_token').not_to be_routable
      end
      it 'PUT has no route to /auth/access_token' do
        expect(:put => '/auth/access_token').not_to be_routable
      end
    end
  end # /auth/access_token

end
