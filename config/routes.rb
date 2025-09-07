Rails.application.routes.draw do
  devise_for :users

  # Dashboard routes
  get "dashboard", to: "dashboard#index", as: :dashboard
  get "dashboard/analytics", to: "dashboard#analytics", as: :dashboard_analytics
  get "dashboard/widgets", to: "dashboard#widgets", as: :dashboard_widgets

  # User account pages
  get "profile", to: "users#profile", as: :profile
  patch "profile", to: "users#update_profile", as: :update_profile
  get "settings", to: "users#settings", as: :settings
  patch "settings", to: "users#update_settings", as: :update_settings
  get "billing", to: "users#billing", as: :billing

  # Keywords resource
  resources :keywords

  # Landing page route
  get "landing", to: "landing#index", as: :landing

  # Static pages
  get "about", to: "pages#about", as: :about
  get "contact", to: "pages#contact", as: :contact
  post "contact", to: "pages#submit_contact", as: :submit_contact

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # Redirect authenticated users to dashboard, others to landing
  authenticated :user do
    root "dashboard#index", as: :authenticated_root
  end

  root "landing#index"
end
