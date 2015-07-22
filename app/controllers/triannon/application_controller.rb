module Triannon
  class ApplicationController < ActionController::Base

    before_action :authorize

    #--- Authentication methods
    #
    # The #access_token_data method is generally available to the
    # application.  The #access_token_generate and #access_token_validate?
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
      session[:access_token] = crypt.encrypt_and_sign([data, timestamp])
    end

    # decrypt, parse and validate access token
    def access_token_valid?(code)
      begin
        if code == session[:access_token]
          identity, salt = session[:access_data]
          key = ActiveSupport::KeyGenerator.new(identity).generate_key(salt)
          crypt = ActiveSupport::MessageEncryptor.new(key)
          data, timestamp = crypt.decrypt_and_verify(code)
          elapsed = Time.now.to_i - timestamp.to_i  # sec since token was issued
          return data if elapsed < Triannon.config[:access_token_expiry]
        end
      rescue ActiveSupport::MessageVerifier::InvalidSignature
        # This is an invalid code, so return nil (a falsy value).
      end
    end

    # Extract access login data from Authorization header, if it is valid.
    # @param headers [Hash] request.headers with 'Authorization'
    # @return login_data [Hash|nil]
    def access_token_data(headers)
      auth = headers['Authorization']
      unless auth.nil? || auth !~ /^Bearer/
        token = auth.split.last
        access_token_valid?(token)
      end
    end


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
      if request.headers['Authorization'].nil?
        render401
        return false
      end
      # Identify an intersection of the user and the authorized workgroups.
      container_groups = container_auth['workgroups'] || []
      match = container_groups & user_workgroups
      if match.empty?
        render403
        false
      else
        true
      end
    end

    # Extract container authorization from the configuration parameters
    # @return authorization [Hash]
    def container_authorization
      container_config = request_container_config
      if container_config.instance_of? Hash
        container_config['auth'] || {}
      else
        {}
      end
    end

    # Map the request root container to config parameters;
    # assume that a request can only map to one root container.
    # If this mapping fails, assume that authorization is OK.
    def request_container_config
      # TODO: refine the matching algorithm, esp if there is more than one
      # match rather than assume it can only match one container.
      request_container = params['anno_root']
      configs = Triannon.config[:ldp]['anno_containers']
      configs[request_container]
    end

    # Extract user workgroups from the access token
    # @return workgroups [Array<String>]
    def user_workgroups
      access_data = access_token_data(request.headers)
      if access_data.instance_of? Hash
        access_data['workgroups'] || []
      else
        []
      end
    end

    def render401
      respond_to do |format|
        format.all { head :unauthorized }
      end
    end

    def render403
      respond_to do |format|
        format.all { head :forbidden }
      end
    end

  end
end
