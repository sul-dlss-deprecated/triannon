module Triannon
  class ApplicationController < ActionController::Base


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
      token = "#{data.to_json};;;#{timestamp}"
      salt  = SecureRandom.random_bytes(64)
      key   = ActiveSupport::KeyGenerator.new(timestamp).generate_key(salt)
      crypt = ActiveSupport::MessageEncryptor.new(key)
      session[:access_key] = key
      session[:access_token] = crypt.encrypt_and_sign(token)
    end

    # decrypt, parse and validate access token
    def access_token_valid?(code)
      if code == session[:access_token]
        key = session[:access_key]
        crypt = ActiveSupport::MessageEncryptor.new(key)
        token = crypt.decrypt_and_verify(code)
        token_data = token.split(';;;')
        identity = JSON.parse(token_data.first)
        timestamp = token_data.last.to_i
        elapsed = Time.now.to_i - timestamp  # sec since token was issued
        return identity if elapsed < Triannon.config[:access_token_expiry]
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

  end
end
