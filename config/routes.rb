Cerberus::Annotations::Engine.routes.draw do
# not sure why this was here ... seems silly?  
#  namespace :annotations do
#    resources :annotations
#  end

  root to: 'annotations#index'

  resources :annotations
end
