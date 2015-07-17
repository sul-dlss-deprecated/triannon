module AuthHelpers

  def access_token
    @access_token ||= begin
      login
      # get '/auth/access_token', {'code' => auth_code}
      get :access_token, {'code' => auth_code}
      data = JSON.parse(response.body)
      data['accessToken']
    end
  end

  def auth_code
    @auth_code ||= begin
      # post '/auth/client_identity', client_credentials.to_json, json_payloads
      # post '/auth/client_identity', client_credentials.to_json
      set_json_headers
      post :client_identity, client_credentials.to_json
      expect(response.status).to eql(200)
      data = JSON.parse(response.body)
      data['authorizationCode']
    end
  end

  def client_credentials
    @client_credentials ||= begin
      # This is an old style hash so the keys are strings that are easier to
      # work with when comparing this data in HTTP responses.
      {'clientId' => 'clientA', 'clientSecret' => 'secretA'}
    end
  end

  def client_credentials_required
    expect(response.status).to eql(401)
    err = JSON.parse(response.body)
    expect(err).not_to be_empty
    expect(err['error']).to eql('invalidClient')
    err
  end

  def login
    # options = json_payloads
    # post '/auth/login', login_credentials.to_json, params
    set_json_headers
    params = {'code' => auth_code}
    post :login, login_credentials.to_json, params
    expect(response.status).to eq(302)
    expect(response).to redirect_to('/')
    expect(response.cookies['login_user']).not_to be_nil
  end

  def login_credentials
    @login_credentials ||= begin
      # This is an old style hash so the keys are strings that are easier to
      # work with when comparing this data in HTTP responses.
      groups = ['org:wg-A','org:wg-B'] # matches config/triannon.yml
      {'userId' => 'userA', 'userSecret' => 'secretA', 'workgroups' => groups}
    end
  end

  def login_credentials_required
    expect(response.status).to eql(401)
    err = JSON.parse(response.body)
    expect(err).not_to be_empty
    expect(err['errorDescription']).to eql('login credentials required')
  end


  # --- Content negotiation utils

  # def accept_json
  #   {'Accept' => 'application/json'}
  # end

  # def content_json
  #   {'Content-Type' => 'application/json'}
  # end

  # def json_payloads
  #   headers = {}
  #   headers.merge!(accept_json)
  #   headers.merge!(content_json)
  #   headers
  # end

  def set_json_headers
    request.headers['Accept'] = 'application/json'
    request.headers['Content-Type'] = 'application/json'
  end

end
