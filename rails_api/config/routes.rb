Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # Mini App routes
  get 'mini-app', to: 'mini_app#index'
  get 'mini-app/:file', to: 'mini_app#serve_static', constraints: { file: /[^\/]+\.(css|js|png|jpg|jpeg|gif|svg|ico)/i }
  get 'mini-app/*path', to: 'mini_app#index'

  namespace :api do
    post 'queries', to: 'queries#create'
    get 'brands', to: 'queries#brands'
    get 'models', to: 'queries#models'
    
    # Vehicle History Engine endpoints
    get 'vehicles/by-partial-vin/:partial_vin', to: 'vehicles#by_partial_vin'
    get 'vehicles/by-fingerprint', to: 'vehicles#by_fingerprint'
    get 'vehicles/by-stock/:source/:stock_number', to: 'vehicles#by_stock'
    get 'vehicles/by-lot/:source/:lot_id', to: 'vehicles#by_lot'
    
    # Payment endpoints
    post 'payments', to: 'payments#create'
    get 'payments/:id', to: 'payments#show'
    get 'payments/:id/result', to: 'payments#result'
    post 'payments/:id/callback', to: 'payments#callback'
    get 'payments/history', to: 'payments#history'
  end
end
