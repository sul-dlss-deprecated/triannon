require_dependency "triannon/application_controller"

require 'openssl'
require 'digest/sha1'

module Triannon
  # Adapted from http://image-auth.iiif.io/api/image/2.1/authentication.html
  class AuthController < ApplicationController
    include RdfResponseFormats


    AUTH_EXPIRY  =   60 # seconds
    TOKEN_EXPIRY = 3600 # seconds


    # OPTIONS /auth
    def options
      if session[:login_user]
        info = service_info_logout
      else
        info = service_info_login
      end
      # TODO: include optional info, such as service_info_client_identity
      return JSON.dump(info)
    end

    #
    # TODO: replace this dummy login method with a secure login authentication
    #
    # http://image-auth.iiif.io/api/image/2.1/authentication.html#login-service
    # @param user [String] A URI parameter, ?user=<user>
    # @param password [String] A URI parameter, ?password=<password>
    # @param account [String] A cookie value containing '<user>:<password>'
    def login
      # The service must set a Cookie for the Access Token Service to retrieve
      # to determine the user information provided by the authentication system.
      user = params[:user] || ''
      pass = params[:password] || ''
      account = cookie[:account] || "#{user}:#{pass}"
      unless account.nil? || account.empty? || account == ':'
        # TODO: check user credentials? (but Triannon has no user db)
        cookie[:account] = nil
        cookie[:login_user] = account
      else
        err = {
          error: 'User unauthorized',
          errorDescription: 'No login details received',
          errorUri: 'http://image-auth.iiif.io/api/image/2.1/authentication.html'
        }
        response.body = JSON.dump(err)
        response.content_type = 'application/json'
        response.status = 401
      end
    end

    # http://image-auth.iiif.io/api/image/2.1/authentication.html#logout-service
    def logout
      cookie[:account] = nil
      cookie[:login_user] = nil
      session[:client_identity] = nil
      session[:client_key] = nil
      session[:client_iv] = nil
      redirect_to root_url, notice: 'Successfully logged out.'
    end

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
