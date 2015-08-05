module Triannon
  class ApplicationController < ActionController::Base

    before_action :authorize

    #--- Authentication methods
    #
    # The #access_token_data method is generally available to the
    # application.  The #access_token_generate and #access_token_valid?
    # methods are consolidated here to provide a unified view of these methods,
    # although the application generally may not need to call them.  They are
    # used specifically in the auth_controller and these methods are tested
    # in the auth_controller_spec.

    # construct and encrypt an access token, using login data
    # save the token into session[:access_token]
    def access_token_generate(data)
      timestamp = Time.now.to_i.to_s # seconds since epoch
      salt  = SecureRandom.base64(64)
      key   = ActiveSupport::KeyGenerator.new(timestamp).generate_key(salt)
      crypt = ActiveSupport::MessageEncryptor.new(key)
      session[:access_data] = [timestamp, salt]
      session[:access_token] = crypt.encrypt_and_sign(data)
    end

    # Extract access login data for a session.
    # @return login_data [Hash] contains login data (empty on failure)
    def access_token_data
      @access_data ||= begin
        data = {}
        auth = request.headers['Authorization']
        if auth.nil? || auth !~ /^Bearer/ || session[:access_token].nil?
          access_token_error
        else
          token = auth.split.last
          if token == session[:access_token]
            timestamp, salt = session[:access_data]
            if access_token_expired?(timestamp)
              access_token_error('Access token expired')
            else
              key = ActiveSupport::KeyGenerator.new(timestamp).generate_key(salt)
              crypt = ActiveSupport::MessageEncryptor.new(key)
              data = crypt.decrypt_and_verify(token)
            end
          else
            access_token_error('Access code does not match login session')
          end
        end
        data
      rescue
        access_token_error('Failed to validate access code')
        data
      end
    end

    def access_token_expired?(timestamp)
      elapsed = Time.now.to_i - timestamp.to_i  # sec since code was issued
      elapsed >= Triannon.config[:access_token_expiry]
    end

    # decrypt, parse and validate access token
    def access_token_valid?
      not access_token_data.empty?
    end

    # Issue an access token error
    def access_token_error(msg=nil, status=401)
      msg ||= 'Access token required'
      err = {
        error: 'invalidRequest',
        errorDescription: msg,
        errorUri: 'http://image-auth.iiif.io/api/image/2.1/authentication.html#access-token-service'
      }
      json_response(err, status)
    end



    # --------------------------------------------------------------------
    # Utility methods

    # @param data [Hash] Hash.to_json is rendered
    # @param status [Integer] HTTP status code
    def json_response(data, status)
      render json: data.to_json, content_type: json_type_accepted, status: status
    end

    # Response content type to match an HTTP accept type for JSON formats
    def json_type_accepted
      mime_type_from_accept(['application/json', 'text/x-json', 'application/jsonrequest'])
    end


    # --------------------------------------------------------------------
    # Private methods

    private

    def authorize
      # Require authorization on POST and DELETE requests.
      auth_methods = ['POST','DELETE']
      return true unless auth_methods.include? request.method
      # Allow any requests to the /auth paths; provided that an
      # anno root container cannot start with 'auth' in the name
      # (which is controlled by the routes constraints).
      return true if request.path =~ /^\/auth/
      authorized_workgroup?
    end

    def authorized_workgroup?
      # If the request does not map to a configured container, allow access.
      container_auth = container_authorization
      return true if container_auth.empty?
      return false unless access_token_valid?
      # Identify an intersection of the user and the authorized workgroups.
      container_groups = container_auth['workgroups'] || []
      match = container_groups & user_workgroups
      if match.empty?
        msg = 'Write access is denied on this annotation container.'
        access_token_error(msg, 403)
        false
      else
        true
      end
    end

    # Extract container authorization from the configuration parameters
    # @return authorization [Hash]
    def container_authorization
      configs = Triannon.config[:ldp]['anno_containers']
      container_config = configs[params['anno_root']]
      if container_config.instance_of? Hash
        container_config['auth'] || {}
      else
        {}
      end
    end

    # Extract user workgroups from the access token
    # @return workgroups [Array<String>]
    def user_workgroups
      access_data = access_token_data
      access_data['workgroups'] || []
    end

  end
end
