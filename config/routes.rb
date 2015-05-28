Triannon::Engine.routes.draw do

  resources :annotations, except: [:update, :edit],
    # show action must explicitly forbid "new", "iiif" and "oa" as id values;  couldn't
    #   figure out how to do it with regexp constraint since beginning and end regex
    #   matchers aren't allowed when enforcing formats for segment (e.g. :id)
    constraints: lambda { |request|
                            id = request.env["action_dispatch.request.path_parameters"][:id]
                            id !~ /^iiif$/ && id !~ /^oa$/ && id !~ /^search$/
                 } do
    collection do
      get 'search', to: 'search#find'
    end
  end

  get '/search', to: 'search#find'

  root to: 'search#find'

  # allow jsonld context in path (only allow iiif or oa as values)
  #   must explicitly forbid "new" as id values;  couldn't figure
  #   out how to do it with regexp constraint since beginning and end regex
  #   matchers aren't allowed when enforcing formats for segment (e.g. :id)
  get '/annotations/:jsonld_context/:id(.:format)', to: 'annotations#show',
    constraints: lambda { |request|
                          jsonld_context = request.env["action_dispatch.request.path_parameters"][:jsonld_context]
                          id = request.env["action_dispatch.request.path_parameters"][:id]
                          (jsonld_context =~ /^iiif$/ || jsonld_context =~ /^oa$/ ) && id !~ /^new$/
                 }

  get '/auth', to: '/auth/developer'
  get '/auth/:provider/callback', to: 'sessions#create'

end
