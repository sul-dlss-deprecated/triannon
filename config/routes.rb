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
    constraints: lambda { |r| anno_root_filter(r) }

  # get -> search controller find action
  get '/annotations/:anno_root/search', to: 'search#find'
  get '/annotations/search', to: 'search#find'
  get '/:anno_root/search', to: 'search#find',
    constraints: lambda { |r| anno_root_filter(r) }
  get '/search', to: 'search#find'

  # get + id -> show action
  get '/annotations/:anno_root/:id(.:format)', to: 'annotations#show',
    constraints: lambda { |r| anno_root_filter(r) && id_filter(r) }
  get '/:anno_root/:id(.:format)', to: 'annotations#show',
    constraints: lambda { |r| anno_root_filter(r) && id_filter(r) }

  # get - id -> index action
  get '/annotations/:anno_root', to: 'annotations#index',
    constraints: lambda { |r| anno_root_filter(r) }
  get '/:anno_root', to: 'annotations#index',
    constraints: lambda { |r| anno_root_filter(r) }

  # post -> create action
  post '/annotations/:anno_root', to: 'annotations#create',
    constraints: lambda { |r| anno_root_filter(r) }
  post '/:anno_root', to: 'annotations#create',
    constraints: lambda { |r| anno_root_filter(r) }

  # delete -> destroy action
  delete '/annotations/:anno_root/:id(.:format)', to: 'annotations#destroy',
    constraints: lambda { |r| anno_root_filter(r) && id_filter(r) }
  delete '/:anno_root/:id(.:format)', to: 'annotations#destroy',
    constraints: lambda { |r| anno_root_filter(r) && id_filter(r) }

  get '/annotations', to: 'search#find'
  root to: 'search#find'

end


def anno_root_filter(request)
  request.path_parameters[:anno_root] !~ /^annotations$|^auth$|^new$|^search$/
end

def id_filter(request)
  request.path_parameters[:id] !~ /^new$|^search$/
end


