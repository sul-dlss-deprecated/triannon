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
      salt  = SecureRandom.random_bytes(64)
      key   = ActiveSupport::KeyGenerator.new(timestamp).generate_key(salt)
      crypt = ActiveSupport::MessageEncryptor.new(key)
      session[:access_key] = key
      session[:access_token] = crypt.encrypt_and_sign([data, timestamp])
    end

    # decrypt, parse and validate access token
    def access_token_valid?(code)
      if code == session[:access_token]
        key = session[:access_key]
        crypt = ActiveSupport::MessageEncryptor.new(key)
        data, timestamp = crypt.decrypt_and_verify(code)
        elapsed = Time.now.to_i - timestamp.to_i  # sec since token was issued
        return data if elapsed < Triannon.config[:access_token_expiry]
      end
      nil
    end

    # Extract access login data from Authorization header, if it is valid.
    # @param headers [Hash] request.headers with 'Authorization'
    # @return login_data [Hash|nil]
    def access_token_data(headers)
      auth = headers['Authorization']
      if auth.nil? || auth !~ /Bearer/
        nil
      else
        token = auth.split[1]
        access_token_valid?(token)
      end
    end


    private

    def authorize
      # Require authorization on POST and DELETE requests.
      return true unless ['POST','DELETE'].include? request.method
      # Allow any requests to the /auth paths; provided that an
      # anno root container cannot start with 'auth' in the name
      # (which is controlled by the routes constraints).
      return true if request.path =~ /^\/auth/
      # Try to map the request root container to config parameters;
      # assume that a request can only map to one root container.
      # If this mapping fails, assume that authorization is OK.
      request_container = params['anno_root'] || request.path
      containers = Triannon.config[:ldp]['anno_containers']
      container = containers.keys.map {|c| c if request_container.include? c }.compact.first
      container_config = containers[container]
      return true if container_config.nil?
      # If there is no authorization configured, allow access.
      container_auth = container_config['auth']
      return true if container_auth.nil?
      auth_workgroups = container_auth['workgroups'] || []
      return true if auth_workgroups.empty?
      # Check the request contains an access token
      access_data = access_token_data(request.headers)
      if access_data.nil?
        render403
      else
        # Identify an intersection of the user and the authorized workgroups.
        user_workgroups = access_data['workgroups'] || []
        match_workgroups = auth_workgroups & user_workgroups
        render403 if match_workgroups.empty?
      end
    end

    def render403
      respond_to do |format|
        format.all { head :forbidden }
      end
    end

  end
end
