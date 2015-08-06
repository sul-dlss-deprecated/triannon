require_dependency "triannon/application_controller"

module Triannon
  # Adapted from http://iiif.io/api/auth
  class AuthController < ApplicationController
    include RdfResponseFormats

    IIIF_AUTH = 'http://iiif.io/api/auth/'

    # HTTP request methods accepted by /auth/login
    # TODO: enable GET when triannon supports true user authentication
    LOGIN_ACCEPT = 'OPTIONS, POST'

    # OPTIONS /auth/login
    def options
      # The request MUST use HTTP OPTIONS
      case request.request_method
      when 'OPTIONS'
        json_response(service_info, 200)
      else
        # The routes should prevent any execution here.
        request_method_error(LOGIN_ACCEPT)
      end
    end

    # POST to /auth/login
    # http://iiif.io/api/auth#login-service
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
    # http://iiif.io/api/auth#logout-service
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
    # http://iiif.io/api/auth#client-identity-service
    # http://iiif.io/api/auth#error-conditions
    # return json body [String] containing: { "authorizationCode": code }
    def client_identity
      return unless process_post?
      return unless process_json?
      data = JSON.parse(request.body.read)
      required_fields = ['clientId', 'clientSecret']
      identity = parse_identity(data, required_fields)
      if identity['clientId'] && identity['clientSecret']
        if authorized_client? identity
          id = identity['clientId']
          pass = identity['clientSecret']
          code = { authorizationCode: auth_code_generate(id, pass) }
          json_response(code, 200)
        else
          err = {
            error: 'invalidClient',
            errorDescription: 'Unknown client credentials',
            errorUri: IIIF_AUTH
          }
          json_response(err, 403)
        end
      else
        err = {
          error: 'missingCredentials',
          errorDescription: 'Requires {"clientId": x, "clientSecret": x}',
          errorUri: IIIF_AUTH
        }
        json_response(err, 401)
      end
    end


    # GET /auth/access_token
    # http://iiif.io/api/auth#access-token-service
    # http://iiif.io/api/auth#error-conditions
    def access_token
      # The cookie established via the login service must be passed to this
      # service. The service should delete the cookie from the login service
      # and create a new cookie that allows the user to access content.
      if session[:login_data]
        if session[:client_data]
          # When an authorization code was obtained using /auth/client_identity,
          # that code must be passed to the Access Token Service as well.
          auth_code = params[:code]
          access_token_granted if auth_code_valid?(auth_code)
        else
          # Without an authentication code, a login session is sufficient for
          # granting an access token.  However, the only way to enable a login
          # session is for an authorized client to provide user data in POST
          # /auth/login, which requires the client to first obtain an
          # authentication code.  Hence, this block of code should never get
          # executed (unless login requirements change).
          access_token_granted
        end
      else
        login_required
      end
    end

    # GET /auth/access_validate
    # Authorize access based on validating an access token
    def access_validate
      if access_token_valid?
        response.status = 200
        render nothing: true
      end
    end

    private

    # --------------------------------------------------------------------
    # Access tokens

    # Grant an access token for authorized access
    def access_token_granted
      cookies.delete(:login_user)
      login_data = session.delete(:login_data)
      access_token_generate(login_data) # saves to session[:access_token]
      data = {
        accessToken: session[:access_token],
        tokenType: 'Bearer',
        expiresIn: Time.now.to_i + Triannon.config[:access_token_expiry]
      }
      json_response(data, 200)
    end

    # --------------------------------------------------------------------
    # User authentication

    # Handles POST /auth/login
    # The request MUST include a URI parameter 'code=client_token' where
    # the 'client_token' has been obtained from /auth/client_identity and
    # the request MUST carry a body with the following JSON template:
    # { "userId" : "ID", "workgroups" : "wgA, wgB" }
    # Note that the current 'SearchWorks' requirements do not specify
    # a 'userSecret' (it's not available).
    def login_handler_post
      return unless process_post?
      return unless process_json?
      auth_code = params[:code]
      if auth_code_valid?(auth_code)
        begin
          data = JSON.parse(request.body.read)
          required_fields = ['userId', 'workgroups']
          identity = parse_identity(data, required_fields)
          # When an authorized client POSTs user data, it is simply accepted.
          if identity['userId'] && identity['workgroups']
            # Coerce workgroups into an Array.
            wg = identity['workgroups'] || []
            wg = wg.split(',') if wg.instance_of? String
            wg.delete_if {|e| e.empty? }
            identity['workgroups'] = wg
            # Save the login_data until an access token is requested.
            # Note that session data must be JSON compatible.
            identity.to_json # check JSON compatibility
            cookies[:login_user] = identity['userId']
            session[:login_data] = identity
            login_successful
          else
            login_required
          end
        rescue
          login_required(422)
        end
      end
    end

    def login_successful
      render nothing: true, status: 200
    end

    def login_required(status=401)
      if request.format == :json
        if status == 401
          err = {
            error: 'missingCredentials',
            errorDescription: 'login credentials required',
            errorUri: IIIF_AUTH
          }
        end
        if status == 422
          err = {
            error: 'invalidRequest',
            errorDescription: 'login credentials cannot be parsed',
            errorUri: IIIF_AUTH
          }
        end
        json_response(err, status)
      end
    end


    # --------------------------------------------------------------------
    # Client authentication

    # Authenticates known clients
    # @param identity [Hash] with fields 'clientId' and 'clientSecret'
    def authorized_client?(identity)
      @clients ||= Triannon.config[:authorized_clients]
      @clients[identity['clientId']] == identity['clientSecret']
    end

    # --------------------------------------------------------------------
    # Authentication tokens

    # construct and encrypt an authorization code
    def auth_code_generate(id, pass)
      identity = "#{id};;;#{pass}"
      timestamp = Time.now.to_i.to_s # seconds since epoch
      salt  = SecureRandom.base64(64)
      key   = ActiveSupport::KeyGenerator.new(identity).generate_key(salt)
      crypt = ActiveSupport::MessageEncryptor.new(key)
      session[:client_data] = [identity, salt]
      session[:client_token] = crypt.encrypt_and_sign([id, timestamp])
    end

    # decrypt, parse and validate authorization code
    def auth_code_valid?(code)
      if code.nil? || session[:client_token].nil?
        auth_code_error
      else
        begin
          if code == session[:client_token]
            identity, salt = session[:client_data]
            key = ActiveSupport::KeyGenerator.new(identity).generate_key(salt)
            crypt = ActiveSupport::MessageEncryptor.new(key)
            data, timestamp = crypt.decrypt_and_verify(code)
            elapsed = Time.now.to_i - timestamp.to_i  # sec since code issued
            if elapsed < Triannon.config[:client_token_expiry]
              return data
            else
              auth_code_error('Authorization code expired')
            end
          else
            msg = 'Unable to validate authorization code'
            auth_code_error(msg)
          end
        rescue ActiveSupport::MessageVerifier::InvalidSignature
          # This is an invalid code, so return false.
        end
      end
      false
    end

    # Issue a client authorization error
    def auth_code_error(msg=nil, status=401)
      msg ||= 'Client authorization required'
      err = {
        error: 'invalidClient',
        errorDescription: msg,
        errorUri: 'http://iiif.io/api/auth#client-identity-service'
      }
      json_response(err, status)
    end

    # --------------------------------------------------------------------
    # Service information data
    # TODO: evaluate whether we need this data

    # return uri [String] the configured Triannon host URI
    def service_base_uri
      uri = RDF::URI.new(Triannon.config[:triannon_base_url])
      uri.to_s.sub(uri.path,'')
    end

    # http://iiif.io/api/auth#login-service
    # return info [Hash] authorization service information
    def service_info
      info = service_info_login
      services = info['service']['service']
      services.push service_info_logout
      services.push service_info_client_identity
      services.push service_info_access_token
      info
    end

    # http://iiif.io/api/auth#login-service
    # return info [Hash] login service information
    def service_info_login
      {
        'service' => {
          '@id' => service_base_uri + '/auth/login',
          'profile' => 'http://iiif.io/api/auth/0/login',
          'label' => 'Login to Triannon',
          'service' => [
            # Related services ...
          ]
        }
      }
    end

    # http://iiif.io/api/auth#logout-service
    # return info [Hash] logout service information
    def service_info_logout
      {
        "@id" => service_base_uri + '/auth/logout',
        "profile" => "http://iiif.io/api/auth/0/logout",
        "label" => "Logout of Triannon"
      }
    end

    # http://iiif.io/api/auth#access-token-service
    # return info [Hash] access token service information
    def service_info_access_token
      {
        "@id" => service_base_uri + '/auth/access_token',
        "profile" => "http://iiif.io/api/auth/0/token",
      }
    end

    # http://iiif.io/api/auth#client-identity-service
    # return info [Hash] client identity service information
    def service_info_client_identity
      {
        "@id" => service_base_uri + '/auth/client_identity',
        "profile" => "http://iiif.io/api/auth/0/clientId",
      }
    end

    # Parse POST JSON data to ensure it contains required fields
    # @param fields [Array<String>] an array of required fields
    def parse_identity(data, fields)
      identity = Hash[fields.map {|f| [f, nil]}]
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
        request_method_error('POST')
        false
      end
    end

    # @param accept [String] a csv for request methods accepted
    def request_method_error(accept)
      logger.debug "Rejected Request Method: #{request.request_method}"
      response.status = 405
      response.headers.merge!({'Allow' => accept})
      if request.format == :json
        err = {
          error: 'invalidRequest',
          errorDescription: "#{request.path} accepts: #{accept}",
          errorUri: IIIF_AUTH
        }
        render json: err.to_json, content_type: json_type_accepted
      end
    end

  end # AuthController
end # Triannon
