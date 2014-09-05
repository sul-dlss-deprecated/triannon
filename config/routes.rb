Cerberus::Annotations::Engine.routes.draw do
  root to: 'annotations#index'

  resources :annotations
end
