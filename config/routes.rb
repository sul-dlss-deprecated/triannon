Triannon::Engine.routes.draw do

  # 1. can't use resourceful routing because of :anno_root (dynamic path segment)
  # 2. couldn't figure out how to exclude specific values with regexp constraint since beginning and end regex matchers
  #    aren't allowed when enforcing formats for path segment (i.e. :anno_root, :id)

  get '/annotations/:anno_root/new', to: 'annotations#new'
  get '/:anno_root/new', to: 'annotations#new',
    constraints: lambda { |request|
                            anno_root = request.path_parameters[:anno_root]
                            id = request.path_parameters[:id]
                            anno_root !~ /^annotations$/ && anno_root !~ /^search$/ && anno_root !~ /^new$/ && id !~ /^search$/ && id !~ /^new$/
                 }

  get '/annotations/:anno_root/:id(.:format)', to: 'annotations#show'
  get '/:anno_root/:id(.:format)', to: 'annotations#show',
    constraints: lambda { |request|
                            anno_root = request.path_parameters[:anno_root]
                            id = request.path_parameters[:id]
                            anno_root !~ /^annotations$/ && anno_root !~ /^search$/ && anno_root !~ /^new$/ && id !~ /^search$/ && id !~ /^new$/
                 }

  get '/annotations/:anno_root', to: 'annotations#index',
    constraints: lambda { |request|
                            anno_root = request.path_parameters[:anno_root]
                            anno_root !~ /^search$/ && anno_root !~ /^new$/
                 }
  get '/:anno_root', to: 'annotations#index',
    constraints: lambda { |request|
                            anno_root = request.path_parameters[:anno_root]
                            anno_root !~ /^annotations$/ && anno_root !~ /^search$/ && anno_root !~ /^new$/
                 }

  post '/annotations/:anno_root', to: 'annotations#create'
  post '/:anno_root', to: 'annotations#create',
    constraints: lambda { |request|
                            anno_root = request.path_parameters[:anno_root]
                            anno_root !~ /^annotations$/ && anno_root !~ /^search$/ && anno_root !~ /^new$/
                 }

  delete '/annotations/:anno_root/:id(.:format)', to: 'annotations#destroy'
  delete '/:anno_root/:id(.:format)', to: 'annotations#destroy',
    constraints: lambda { |request|
                            anno_root = request.path_parameters[:anno_root]
                            id = request.path_parameters[:id]
                            anno_root !~ /^annotations$/ && anno_root !~ /^search$/ && anno_root !~ /^new$/ && id !~ /^search$/ && id !~ /^new$/
                 }

  get '/annotations/:anno_root/search', to: 'search#find'
  get '/:anno_root/search', to: 'search#find',
    constraints: lambda { |request|
                            anno_root = request.path_parameters[:anno_root]
                            anno_root !~ /^annotations$/ && anno_root !~ /^search$/ && anno_root !~ /^new$/
                 }
  get '/search', to: 'search#find'

  root to: 'search#find'

=begin
  resources :annotations, except: [:update, :edit],
    # show action must explicitly forbid "search" as id value;  couldn't
    #   figure out how to do it with regexp constraint since beginning and end regex
    #   matchers aren't allowed when enforcing formats for segment (e.g. :id)
    constraints: lambda { |request|
                            id = request.env["action_dispatch.request.path_parameters"][:id]
                            id !~ /^search$/
                 } do
    collection do
      get 'search', to: 'search#find'
    end
  end
=end


end
