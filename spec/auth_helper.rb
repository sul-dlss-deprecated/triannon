module AuthHelpers

  def access_token
    @access_token ||= begin
      login
      get :access_token, {'code' => auth_code}
      data = JSON.parse(response.body)
      data['accessToken']
    end
  end

  def access_token_headers
    headers = json_payloads
    headers.merge!( { 'Authorization' => "Bearer #{access_token}" } )
  end

  def auth_code
    @auth_code ||= begin
      json_request_headers
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
    json_request_headers
    params = {'code' => auth_code}
    post :login, login_credentials.to_json, params
    expect(response.status).to eq(200)
    expect(response.cookies['login_user']).not_to be_nil
  end

  def login_credentials
    @login_credentials ||= begin
      # This is an old style hash so the keys are strings that are easier to
      # work with when comparing this data in HTTP responses.
      groups = ['org:wg-A','org:wg-B'] # matches config/triannon.yml
      {'userId' => 'userA', 'workgroups' => groups}
    end
  end

  def login_credentials_required
    expect(response.status).to eql(401)
    err = JSON.parse(response.body)
    expect(err).not_to be_empty
    expect(err['errorDescription']).to eql('login credentials required')
  end

  def login_credentials_unauthorized
    @login_credentials_unauthorized ||= begin
      # This is an old style hash so the keys are strings that are easier to
      # work with when comparing this data in HTTP responses.
      groups = ['org:wg-X'] # does not matche config/triannon.yml
      {'userId' => 'userA', 'workgroups' => groups}
    end
  end


  # --- Content negotiation utils

  def accept_json
    {'Accept' => 'application/json'}
  end

  def content_json
    {'Content-Type' => 'application/json'}
  end

  def json_payloads
    {}.merge(accept_json).merge(content_json)
  end

  def json_request_headers
    request.headers.merge!(json_payloads)
  end

end
