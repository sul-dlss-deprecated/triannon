require_dependency "triannon/application_controller"

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
        session[:login_user] = user
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
      unless request.post?
        logger.debug "Rejected Request Method: #{request.request_method}"
        err = {
          error: 'invalidRequest',
          errorDescription: '/auth/client_identity only accepts POST requests',
          errorUri: 'http://image-auth.iiif.io/api/image/2.1/authentication.html'
        }
        response.headers.merge!(Allow: 'POST')
        return render_json(err, 405)
      end
      unless request.headers['Content-Type'] =~ /json/
        logger.debug "Rejected Content-Type: #{request.headers['Content-Type']}"
        return render :nothing => true, :status => 415
      end
      # The request MUST carry a body with the following JSON template:
      # {
      #   "clientId" : "CLIENT_ID_HERE",
      #   "clientSecret" : "CLIENT_SECRET_HERE"
      # }
      identity = JSON.parse(request.body.read)
      unless identity.has_key?('clientId') && identity.has_key?('clientSecret')
        err = {
          error: 'invalidRequest',
          errorDescription: "/auth/client_identity requires 'clientId' and 'clientSecret' fields",
          errorUri: 'http://image-auth.iiif.io/api/image/2.1/authentication.html'
        }
        return render_json(err, 400)
      end
      if authorized_client? identity
        code = { authorizationCode: auth_code_generate(identity) }
        return render_json(code, 200)
      else
        err = {
          error: 'invalidClient',
          errorDescription: 'Unable to authorize client',
          errorUri: ''
        }
        return render_json(err, 401)
      end
    end

    # GET /auth/token
    # http://image-auth.iiif.io/api/image/2.1/authentication.html#access-token-service
    # http://image-auth.iiif.io/api/image/2.1/authentication.html#error-conditions
    def access_token
      # The cookie established via the login service must be passed to this
      # service. The service should delete the cookie from the login service
      # and create a new cookie that allows the user to access content.

      key = session[:client_auth_key]
      if key.nil?
        # No authorization code has been issued.
        if session[:login_user]
          # A login session is current, that is sufficient
          # for granting an access token.
          cookies.delete(:login_user)
          session.delete(:login_user)
          session[:access_token] = access_code_generate
          data = {
            accessToken: session[:access_token],
            tokenType: 'Bearer',
            expiresIn: TOKEN_EXPIRY
          }
          return render_json(data, 200)
        else
          redirect_to '/auth/login'
        end
      elsif params[:code]
        # When an authorization code was obtained using /auth/client_identity,
        # that code must be passed to the Access Token Service as well.

        # TODO: require an authenticated login also?
        # if session[:login_user] && auth_code_valid?(params[:code])

        if auth_code_valid?(params[:code])
          # The valid authorization code is sufficient to grant
          # an access token.
          data = {
            accessToken: access_code_generate,
            tokenType: 'Bearer',
            expiresIn: TOKEN_EXPIRY
          }
          return render_json(data, 200)
        else
          err = {
            error: 'invalidClient',
            errorDescription: 'Unable to validate authorization code',
            errorUri: ''
          }
          return render_json(err, 401)
        end
      else
        err = {
          error: 'invalidRequest',
          errorDescription: 'Unable to authorize access token',
          errorUri: ''
        }
        return render_json(err, 401)
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
      salt  = SecureRandom.random_bytes(64)
      key   = ActiveSupport::KeyGenerator.new(pass).generate_key(salt)
      crypt = ActiveSupport::MessageEncryptor.new(key)
      session[:client_auth_key] = key
      crypt.encrypt_and_sign(auth_code)
    end

    # decrypt, parse and validate authorization code
    def auth_code_valid?(code)
      key = session[:client_auth_key]
      crypt = ActiveSupport::MessageEncryptor.new(key)
      auth_code = crypt.decrypt_and_verify(code)
      if auth_code.include?(session[:client_identity]['clientId'])
        timestamp = auth_code.split(';;;').last.to_i
        elapsed = Time.now.to_i - timestamp  # sec since auth code was issued
        return true if elapsed < AUTH_EXPIRY # allow 1 minute for authorization
      end
      return false
    end


    # --------------------------------------------------------------------
    # Access tokens

    # construct and encrypt an access token
    def access_code_generate
      timestamp = Time.now.to_i.to_s # seconds since epoch
      token = "#{SecureRandom.uuid};;;#{timestamp}"
      session[:access_token] = token
      salt  = SecureRandom.random_bytes(64)
      key   = ActiveSupport::KeyGenerator.new(timestamp).generate_key(salt)
      crypt = ActiveSupport::MessageEncryptor.new(key)
      session[:client_access_key] = key
      crypt.encrypt_and_sign(token)
    end

    # decrypt, parse and validate access token
    def access_code_valid?(code)
      key = session[:client_access_key]
      crypt = ActiveSupport::MessageEncryptor.new(key)
      token = crypt.decrypt_and_verify(code)
      if token.eql?(session[:access_token])
        timestamp = token.split(';;;').last.to_i
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


    private

    # Response content type to match an HTTP accept type for JSON formats
    def json_type_accepted
      mime_type_from_accept(['application/json', 'text/x-json', 'application/jsonrequest'])
    end

    # @param data [Hash] Hash.to_json is rendered
    # @param status [Integer] HTTP status code
    def render_json(data, status)
      response.status = status
      respond_to do |format|
        format.json {
          render :json => data.to_json, content_type: json_type_accepted
        }
      end
      # return render :nothing => true, :status => 415
    end

  end # AuthController
end # Triannon
