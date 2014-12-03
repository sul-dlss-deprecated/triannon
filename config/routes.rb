Triannon::Engine.routes.draw do
  root to: 'annotations#index'

  # show action must explicitly forbid "iiif" or "oa" as id values;  couldn't
  #  figure out how to do it with regexp constraint since beginning and end 
  #  matchers aren't allowed when enforcing formats for segment (e.g. :id)
  get '/annotations/:id(.:format)', to: 'annotations#show', 
    constraints: lambda { |request| 
                            id = request.env["action_dispatch.request.path_parameters"][:id]
                            id !~ /^iiif$/ && id !~ /^oa$/ 
                        }

  resources :annotations, :except => [:update, :edit, :show]

  # allow jsonld context in path
  get '/annotations/:jsonld_context/:id(.:format)', to: 'annotations#show', jsonld_context: /iiif|oa/
  
end
