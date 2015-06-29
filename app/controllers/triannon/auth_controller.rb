require_dependency "triannon/application_controller"

module Triannon
  # Adapted from http://image-auth.iiif.io/api/image/2.1/authentication.html
  class AuthController < ApplicationController
    include RdfResponseFormats

    # HTTP request methods accepted by /auth/login
    # TODO: enable GET when triannon supports true user authentication
    LOGIN_ACCEPT = 'OPTIONS, POST'

    # OPTIONS /auth/login
    def options
      # The request MUST use HTTP OPTIONS
      case request.request_method
      when 'OPTIONS'
        if cookies[:login_user]
          info = service_info_logout
        else
          info = service_info_login
        end
        # TODO: include optional info, such as service_info_client_identity
        json_response(info, 200)
      else
        # The routes should prevent any execution here.
        request_method_error(LOGIN_ACCEPT)
      end
    end

    # POST to /auth/login
    # http://image-auth.iiif.io/api/image/2.1/authentication.html#login-service
    def login
      # The service must set a Cookie for the Access Token Service to retrieve
      # to determine the user information provided by the authentication system.
      case request.request_method
      when 'POST'
        login_handler_post
      else
        # The routes should prevent any execution here.
        request_method_error(LOGIN_ACCEPT)
      end
    end

    # GET /auth/logout
    # http://image-auth.iiif.io/api/image/2.1/authentication.html#logout-service
    def logout
      case request.request_method
      when 'GET'
        cookies.delete(:login_user)
        reset_session
        redirect_to root_url, notice: 'Successfully logged out.'
      else
        # The routes should prevent any execution here.
        request_method_error('GET')
      end
    end

    # POST /auth/client_identity
    # A request MUST carry a body with:
    # { "clientId" : "ID", "clientSecret" : "SECRET" }
    # http://image-auth.iiif.io/api/image/2.1/authentication.html#client-identity-service
    # http://image-auth.iiif.io/api/image/2.1/authentication.html#error-conditions
    # return json body [String] containing: { "authorizationCode": code }
    def client_identity
      return unless process_post?
      return unless process_json?
      required_fields = ['clientId', 'clientSecret']
      identity = parse_identity(required_fields)
      if identity['clientId'] && identity['clientSecret']
        if authorized_client? identity
          code = { authorizationCode: auth_code_generate(identity) }
          return json_response(code, 200)
        else
          err = {
            error: 'invalidClient',
            errorDescription: 'Invalid client credentials',
            errorUri: 'http://image-auth.iiif.io/api/image/2.1/authentication.html'
          }
          json_response(err, 403)
        end
      else
        err = {
          error: 'invalidClient',
          errorDescription: 'Insufficient client data for authentication',
          errorUri: 'http://image-auth.iiif.io/api/image/2.1/authentication.html'
        }
        json_response(err, 401)
      end
    end


    # GET /auth/token
    # http://image-auth.iiif.io/api/image/2.1/authentication.html#access-token-service
    # http://image-auth.iiif.io/api/image/2.1/authentication.html#error-conditions
    def access_token
      # The cookie established via the login service must be passed to this
      # service. The service should delete the cookie from the login service
      # and create a new cookie that allows the user to access content.
      if session[:login_user]
        if session[:client_auth_key]
          # When an authorization code was obtained using /auth/client_identity,
          # that code must be passed to the Access Token Service as well.
          auth_code = params[:code]
          if auth_code.nil?
            auth_code_required
          elsif auth_code_valid?(auth_code)
            grant_access_token
          else
            auth_code_invalid
          end
        else
          # Without any authorization token, a login session is sufficient
          # authentication for granting an access token.  Note, however, that
          # the only way to enable a login session is for an authorized client
          # to provide user data in POST /auth/login and that requires the
          # client to first obtain an authentication code, so this block of
          # code should never get executed (unless login requirements change).
          grant_access_token
        end
      else
        login_required
      end
    end

    # GET /auth/access_validate
    # Authorize access based on validating an access token
    def access_validate
      auth = request.headers['Authorization']
      if auth.nil? || auth !~ /Bearer/
        access_token_required
      else
        token = auth.split[1]
        if access_token_valid?(token)
          response.status = 200
          render nothing: true
        else
          access_token_invalid
        end
      end
    end


    private

    # --------------------------------------------------------------------
    # User authentication

    # Handles POST /auth/login
    # The request MUST include a URI parameter 'code=client_token' where
    # the 'client_token' has been obtained from /auth/client_identity and
    # the request MUST carry a body with the following JSON template:
    # { "userId" : "ID", "userSecret" : "SECRET" }
    def login_handler_post
      return unless process_post?
      return unless process_json?
      auth_code = params[:code]
      if auth_code.nil?
        auth_code_required
      elsif auth_code_valid?(auth_code)
        required_fields = ['userId', 'userSecret']
        identity = parse_identity(required_fields)
        # When an authorized client POSTs user data, it is simply accepted.
        if identity['userId']
          login_update(identity['userId'])
          redirect_to root_url, notice: 'Successfully logged in.'
        else
          login_required
        end
      else
        auth_code_invalid
      end
    end

    def login_update(data)
      cookies[:login_user] = data
      session[:login_user] = data
    end

    def login_required
      if request.format == :html
        request_http_basic_authentication
      elsif request.format == :json
        response.headers["WWW-Authenticate"] = %(Basic realm="Application")
        err = {
          error: '401 Unauthorized',
          errorDescription: 'login credentials required',
          errorUri: 'http://image-auth.iiif.io/api/image/2.1/authentication.html'
        }
        json_response(err, 401)
      end
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
        return true if elapsed < Triannon.config[:client_token_expiry]
      end
      false
    end

    # Issue a 403 for invalid client authorization codes
    def auth_code_invalid
      err = {
        error: 'invalidClient',
        errorDescription: 'Unable to validate authorization code',
        errorUri: ''
      }
      json_response(err, 403)
    end

    # Issue a 401 to challenge for a client authorization code
    def auth_code_required
      err = {
        error: 'invalidClient',
        errorDescription: 'authorization code is required',
        errorUri: ''
      }
      json_response(err, 401)
    end


    # --------------------------------------------------------------------
    # Access tokens

    # construct and encrypt an access token
    def access_token_generate
      timestamp = Time.now.to_i.to_s # seconds since epoch
      token = "#{SecureRandom.uuid};;;#{timestamp}"
      salt  = SecureRandom.random_bytes(64)
      key   = ActiveSupport::KeyGenerator.new(timestamp).generate_key(salt)
      crypt = ActiveSupport::MessageEncryptor.new(key)
      session[:client_access_key] = key
      crypt.encrypt_and_sign(token)
    end

    # decrypt, parse and validate access token
    def access_token_valid?(code)
      if code == session[:access_token]
        key = session[:client_access_key]
        crypt = ActiveSupport::MessageEncryptor.new(key)
        token = crypt.decrypt_and_verify(code)
        timestamp = token.split(';;;').last.to_i
        elapsed = Time.now.to_i - timestamp  # sec since token was issued
        return true if elapsed < Triannon.config[:access_token_expiry]
      end
      false
    end

    # Grant an access token for authorized access
    def grant_access_token
      cookies.delete(:login_user)
      session.delete(:login_user)
      session[:access_token] = access_token_generate
      data = {
        accessToken: session[:access_token],
        tokenType: 'Bearer',
        expiresIn: Triannon.config[:access_token_expiry]
      }
      json_response(data, 200)
    end

    # Issue a 403 for invalid access token
    def access_token_invalid
      err = {
        error: 'invalidAccess',
        errorDescription: 'invalid access token',
        errorUri: ''
      }
      json_response(err, 403)
    end

    # Issue a 401 to challenge for a client access token
    def access_token_required
      err = {
        error: 'invalidAccess',
        errorDescription: 'access token is required',
        errorUri: ''
      }
      json_response(err, 401)
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


    # --------------------------------------------------------------------
    # Utility methods


    # @param data [Hash] Hash.to_json is rendered
    # @param status [Integer] HTTP status code
    def json_response(data, status)
      response.status = status
      respond_to do |format|
        format.json {
          render json: data.to_json, content_type: json_type_accepted
        }
        format.html {
          render nothing: true
        }
      end
    end

    # Response content type to match an HTTP accept type for JSON formats
    def json_type_accepted
      mime_type_from_accept(['application/json', 'text/x-json', 'application/jsonrequest'])
    end

    # Parse POST JSON data to ensure it contains required fields
    # @param fields [Array<String>] an array of required fields
    def parse_identity(fields)
      identity = Hash[fields.map {|f| [f, nil]}]
      data = JSON.parse(request.body.read)
      if fields.map {|f| data.key? f }.all?
        fields.each {|f| identity[f] = data[f] }
      end
      identity
    end

    # Is the request content type JSON?  If not, issue a 415 error.
    def process_json?
      if request.headers['Content-Type'] =~ /json/
        true
      else
        logger.debug "Rejected Content-Type: #{request.headers['Content-Type']}"
        render nothing: true, status: 415
        false
      end
    end

    # Is the request method POST?  If not, issue a 405 error.
    def process_post?
      if request.post?
        true
      else
        logger.debug "Rejected Request Method: #{request.request_method}"
        err = {
          error: 'invalidRequest',
          errorDescription: "#{request.path} accepts POST requests, not #{request.request_method}",
          errorUri: 'http://image-auth.iiif.io/api/image/2.1/authentication.html'
        }
        response.headers.merge!(Allow: 'POST')
        json_response(err, 405)
        false
      end
    end

    # @param accept [String] a csv for request methods accepted
    def request_method_error(accept)
      logger.debug "Rejected Request Method: #{request.request_method}"
      response.status = 405
      response.headers.merge!(Allow: accept)
      respond_to do |format|
        format.json {
          err = {
            error: 'invalidRequest',
            errorDescription: "#{request.path} accepts: #{accept}",
            errorUri: 'http://image-auth.iiif.io/api/image/2.1/authentication.html'
          }
          render json: err.to_json, content_type: json_type_accepted
        }
        format.html {
          render nothing: true
        }
      end
    end

  end # AuthController
end # Triannon
