Triannon::Engine.routes.draw do
  root to: 'annotations#index'

  # show action must explicitly forbid "new", "iiif" and "oa" as id values;  couldn't
  #  figure out how to do it with regexp constraint since beginning and end regex
  #  matchers aren't allowed when enforcing formats for segment (e.g. :id)
  get '/annotations/:id(.:format)', to: 'annotations#show', 
    constraints: lambda { |request| 
                            id = request.env["action_dispatch.request.path_parameters"][:id]
                            id !~ /^new$/ && id !~ /^iiif$/ && id !~ /^oa$/ 
                        }

  resources :annotations, :except => [:update, :edit, :show]

  # allow jsonld context in path (only allow iiif or oa as values)
  # must explicitly forbid "new" as id values;  couldn't
  #  figure out how to do it with regexp constraint since beginning and end regex
  #  matchers aren't allowed when enforcing formats for segment (e.g. :id)
  get '/annotations/:jsonld_context/:id(.:format)', to: 'annotations#show', 
    constraints: lambda { |request| 
                          jsonld_context = request.env["action_dispatch.request.path_parameters"][:jsonld_context]
                          id = request.env["action_dispatch.request.path_parameters"][:id]
                          (jsonld_context =~ /^iiif$/ || jsonld_context =~ /^oa$/ ) && id !~ /^new$/
                      }
  
end
