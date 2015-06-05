require_dependency "triannon/application_controller"

require 'openssl'
require 'digest/sha1'

module Triannon
  # Adapted from http://image-auth.iiif.io/api/image/2.1/authentication.html
  class AuthController < ApplicationController
    include RdfResponseFormats

    AUTH_EXPIRY  =   60 # seconds
    TOKEN_EXPIRY = 3600 # seconds

    # OPTIONS /auth/login
    def options
      # The request MUST use HTTP OPTIONS
      unless request.options?
        err = {
          error: "invalidRequest",
          errorDescription: "/auth/login accepts GET or OPTIONS requests",
          errorUri: "http://image-auth.iiif.io/api/image/2.1/authentication.html"
        }
        response.body = JSON.dump(err)
        response.content_type = 'application/json'
        response.headers.merge!(Allow: 'GET, OPTIONS')
        response.status = 405
      end
      if cookies[:login_user]
        info = service_info_logout
      else
        info = service_info_login
      end
      # TODO: include optional info, such as service_info_client_identity
      # accept_return_type = mime_type_from_accept(['application/json', 'text/x-json', 'application/jsonrequest'])
      render :json => info.to_json, content_type: 'application/json' #accept_return_type
    end

    # GET /auth/login
    # HTTP basic authentication
    # http://image-auth.iiif.io/api/image/2.1/authentication.html#login-service
    def login
      # The service must set a Cookie for the Access Token Service to retrieve
      # to determine the user information provided by the authentication system.
      if user = authenticate_with_http_basic { |u, p| authorized_user(u, p) }
        cookies[:login_user] = user
        redirect_to root_url, notice: 'Successfully logged in.'
      else
        respond_to do |format|
          format.html {
            request_http_basic_authentication
          }
          format.json {
            err = {
              error: '401 Unauthorized',
              errorDescription: 'invalid login details received',
              errorUri: 'http://image-auth.iiif.io/api/image/2.1/authentication.html'
            }
            response.status = 401
            accept_return_type = mime_type_from_accept(['application/json', 'text/x-json', 'application/jsonrequest'])
            render :json => err.to_json, content_type: accept_return_type
          }
        end
      end
    end

    # GET /auth/logout
    # http://image-auth.iiif.io/api/image/2.1/authentication.html#logout-service
    def logout
      cookies.delete(:login_user)
      reset_session
      redirect_to root_url, notice: 'Successfully logged out.'
    end

    # POST /auth/client_identity
    # http://image-auth.iiif.io/api/image/2.1/authentication.html#client-identity-service
    # http://image-auth.iiif.io/api/image/2.1/authentication.html#error-conditions
    # return json body [String] containing: { "authorizationCode": code }
    def client_identity
      # The request MUST use HTTP POST
      unless request.post?
        err = {
          error: "invalidRequest",
          errorDescription: "/auth/client_identity only accepts POST requests",
          errorUri: "http://image-auth.iiif.io/api/image/2.1/authentication.html"
        }
        response.body = JSON.dump(err)
        response.content_type = 'application/json'
        response.headers.merge!(Allow: 'POST')
        response.status = 405
      end
      # The request MUST carry a body with the following JSON template:
      # {
      #   "clientId" : "CLIENT_ID_HERE",
      #   "clientSecret" : "CLIENT_SECRET_HERE"
      # }
      identity = JSON.parse(request.body)
      unless identity.has_key?('clientId')
        err = {
          error: "invalidRequest",
          errorDescription: "/auth/client_identity requires 'clientId' field",
          errorUri: "http://image-auth.iiif.io/api/image/2.1/authentication.html"
        }
        response.body = JSON.dump(err)
        response.content_type = 'application/json'
        response.status = 400
      end
      unless identity.has_key?('clientSecret')
        err = {
          error: "invalidRequest",
          errorDescription: "/auth/client_identity requires 'clientSecret' field",
          errorUri: "http://image-auth.iiif.io/api/image/2.1/authentication.html"
        }
        response.body = JSON.dump(err)
        response.content_type = 'application/json'
        response.status = 400
      end
      if authorized_client? identity
        code = auth_code_generate(identity)
        body = JSON.dump({ "authorizationCode" => code })
        response.body = body
        response.content_type = 'application/json'
        response.status = 200
      else
        err = {
          error: "invalidClient",
          errorDescription: "Unable to authorize client",
          errorUri: ""
        }
        response.body = JSON.dump(err)
        response.content_type = 'application/json'
        response.status = 401
      end
    end

    # GET /auth/token
    # http://image-auth.iiif.io/api/image/2.1/authentication.html#access-token-service
    # http://image-auth.iiif.io/api/image/2.1/authentication.html#error-conditions
    def access_token
      # The cookie established via the login service must be passed to this
      # service. The service should delete the cookie from the login service
      # and create a new cookie that allows the user to access the image
      # content.
      # TODO: replace the login cookie

      # If an authorization code was obtained using the Client Identity
      # Service, then this must be passed to the Access Token Service as well.
      # The code is passed using a query parameter to the service called `code`
      # with the authorization code as the value.
      if params[:code]
        if auth_code_valid?(params[:code])
          token = access_code_generate
          token = {
            accessToken: token,
            tokenType: "Bearer",
            expiresIn: TOKEN_EXPIRY
          }
          response.body = JSON.dump(token)
          response.content_type = 'application/json'
          response.status = 200
        else
          err = {
            error: "invalidClient",
            errorDescription: "Unable to validate authorization code",
            errorUri: ""
          }
          response.body = JSON.dump(err)
          response.content_type = 'application/json'
          response.status = 401
        end
      else
        # Use login cookie?
        # cookie[:login_user] = nil
        #
      end
    end


    private

    # --------------------------------------------------------------------
    # User authentication
    # TODO: replace this section with a fully-fledged user authentication

    # Authenticates known users
    # @param username [String]
    # @param password [String]
    def authorized_user(username, password)
      username if authorized_users[username] == password
    end

    # Sets a hash of authorized user data key:value pairs that correspond to
    # the login service parameters named 'username':'password';
    # the data is provided by configuration.
    def authorized_users
      @authorized_users ||= Triannon.config[:authorized_users]
    end


    # --------------------------------------------------------------------
    # Client authentication

    # Authenticates known clients
    # @param identity [Hash] with fields 'clientId' and 'clientSecret'
    def authorized_client?(identity)
      authorized_clients[identity['clientId']] == identity['clientSecret']
    end

    # Sets a hash of authorized client data key:value pairs that correspond to
    # the client_identity service parameters named 'clientId':'clientSecret';
    # the data is provided by configuration.
    def authorized_clients
      @authorized_clients ||= Triannon.config[:authorized_clients]
    end


    # --------------------------------------------------------------------
    # Authentication tokens

    # construct and encrypt an authorization code
    def auth_code_generate(identity)
      session[:client_identity] = identity
      id = identity['clientId']
      pass = identity['clientSecret']
      timestamp = Time.now.to_i # seconds since epoch
      auth_code = "#{id};;;#{timestamp}"
      # http://stackoverflow.com/questions/4721423/native-ruby-methods-for-compressing-encrypt-strings
      c = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
      c.encrypt
      c.key = key = Digest::SHA1.hexdigest(pass)
      c.iv = iv = c.random_iv
      session[:client_key] = key
      session[:client_iv] = iv
      e = c.update(auth_code)
      e << c.final
      e
    end

    # decrypt, parse and validate authorization code
    def auth_code_valid?(code)
      # http://stackoverflow.com/questions/4721423/native-ruby-methods-for-compressing-encrypt-strings
      c = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
      c.decrypt
      c.key = session[:client_key]
      c.iv = session[:client_iv]
      d = c.update(code)
      d << c.final
      if d.include?(session[:client_identity]['clientId'])
        timestamp = d.split(';;;').last
        elapsed = Time.now.to_i - timestamp  # sec since auth code was issued
        return true if elapsed < AUTH_EXPIRY # allow 1 minute for authorization
      end
      return false
    end


    # --------------------------------------------------------------------
    # Access tokens

    # construct and encrypt an authorization code
    def access_code_generate
      token = "#{SecureRandom.uuid};;;#{Time.now.to_i}"
      session[:access_token] = token
      # http://stackoverflow.com/questions/4721423/native-ruby-methods-for-compressing-encrypt-strings
      c = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
      c.encrypt
      c.key = session[:client_key]
      c.iv = session[:client_iv]
      e = c.update(token)
      e << c.final
      e
    end

    # decrypt, parse and validate access token
    def access_code_valid?(code)
      # http://stackoverflow.com/questions/4721423/native-ruby-methods-for-compressing-encrypt-strings
      c = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
      c.decrypt
      c.key = session[:client_key]
      c.iv = session[:client_iv]
      d = c.update(code)
      d << c.final
      if d.eql?(session[:access_token])
        timestamp = d.split(';;;').last
        elapsed = Time.now.to_i - timestamp  # sec since token was issued
        return true if elapsed < TOKEN_EXPIRY
      end
      return false
    end


    # --------------------------------------------------------------------
    # Service information data
    # TODO: evaluate whether we need this data

    # return uri [String] the configured Triannon host URI
    def service_base_uri
      uri = RDF::URI.new(Triannon.config[:triannon_base_url])
      uri.to_s.sub(uri.path,'')
    end

    # http://image-auth.iiif.io/api/image/2.1/authentication.html#access-token-service
    # return info [Hash] access token service information
    def service_info_access_token
      {
        service: {
          "@id" => service_base_uri + '/auth/access_token',
          "profile" => "http://iiif.io/api/image/2/auth/token",
          "label" => "Request Access Token for Triannon"
        }
      }
    end

    # http://image-auth.iiif.io/api/image/2.1/authentication.html#client-identity-service
    # return info [Hash] client identity service information
    def service_info_client_identity
      {
        service: {
          "@id" => service_base_uri + '/auth/client_identity',
          "profile" => "http://iiif.io/api/image/2/auth/clientId"
        }
      }
    end

    # http://image-auth.iiif.io/api/image/2.1/authentication.html#login-service
    # return info [Hash] login service information
    def service_info_login
      {
        service: {
          "@id" => service_base_uri + '/auth/login',
          "profile" => "http://iiif.io/api/image/2/auth/login",
          "label" => "Login to Triannon"
        }
      }
    end

    # http://image-auth.iiif.io/api/image/2.1/authentication.html#logout-service
    # return info [Hash] logout service information
    def service_info_logout
      {
        service: {
          "@id" => service_base_uri + '/auth/logout',
          "profile" => "http://iiif.io/api/image/2/auth/logout",
          "label" => "Logout of Triannon"
        }
      }
    end

  end # AuthController
end # Triannon
