Triannon::Engine.routes.draw do

  # Authentication routes; these must precede '/:anno_root/*' and they
  # preclude the use of an anno root named 'auth'.
  match '/auth/login', to: 'auth#options', via: [:options]
  match '/auth/login', to: 'auth#login', via: [:get]
  get '/auth/logout', to: 'auth#logout'
  get '/auth/access_token', to: 'auth#access_token'
  post '/auth/client_identity', to: 'auth#client_identity'

  # 1. can't use resourceful routing because of :anno_root (dynamic path segment)

  # 2. couldn't figure out how to exclude specific values with regexp constraint since beginning and end regex matchers
  #    aren't allowed when enforcing formats for path segment (i.e. :anno_root, :id)

  # get -> new action
  get '/annotations/:anno_root/new', to: 'annotations#new'
  get '/:anno_root/new', to: 'annotations#new',
    constraints: lambda { |request| anno_container_exclusions request }

  # get -> search controller find action
  get '/annotations/:anno_root/search', to: 'search#find'
  get '/annotations/search', to: 'search#find'
  get '/:anno_root/search', to: 'search#find',
    constraints: lambda { |request| anno_container_exclusions request }
  get '/search', to: 'search#find'

  # get w id -> show action
  get '/annotations/:anno_root/:id(.:format)', to: 'annotations#show',
    constraints: lambda { |request| annotations_container_exclusions request }
  get '/:anno_root/:id(.:format)', to: 'annotations#show',
    constraints: lambda { |request| anno_container_exclusions request }

  # get no id -> index action
  get '/annotations/:anno_root', to: 'annotations#index',
    constraints: lambda { |request| annotations_container_exclusions request }
  get '/:anno_root', to: 'annotations#index',
    constraints: lambda { |request| anno_container_exclusions request }

  # post -> create action
  post '/annotations/:anno_root', to: 'annotations#create',
    constraints: lambda { |request| annotations_container_exclusions request }
  post '/:anno_root', to: 'annotations#create',
    constraints: lambda { |request| anno_container_exclusions request }

  # delete -> destroy action
  delete '/annotations/:anno_root/:id(.:format)', to: 'annotations#destroy',
    constraints: lambda { |request| annotations_container_exclusions request }
  delete '/:anno_root/:id(.:format)', to: 'annotations#destroy',
    constraints: lambda { |request| anno_container_exclusions request }

  get '/annotations', to: 'search#find'
  root to: 'search#find'

end


def anno_container_exclusions(request)
  anno_root = request.path_parameters[:anno_root]
  anno_root !~ /^annotations|auth|new|search$/ && id_exclusions(request)
end

def annotations_container_exclusions(request)
  anno_root = request.path_parameters[:anno_root]
  anno_root !~ /^auth|new|search$/ && id_exclusions(request)
end

def id_exclusions(request)
  return true if request.path_parameters[:id].nil?
  request.path_parameters[:id] !~ /^new|search$/
end


