Cerberus::Annotations::Engine.routes.draw do
  namespace :annotations do
    resources :annotations
  end

  root to: 'annotations#index'

  resources :annotations
end
