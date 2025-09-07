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
  
  # Notifications
  resources :notifications, only: [:index] do
    member do
      patch :mark_as_read
    end
    collection do
      patch :mark_all_as_read
    end
  end

  # Keywords resource
  resources :keywords
  
  # Mentions resource
  resources :mentions, only: [:index, :show, :destroy]

  # Integrations resource with custom actions
  resources :integrations do
    member do
      post :connect
      post :disconnect
      post :sync
      get :logs
    end

    collection do
      get :health_check
    end
  end

  # Leads resource with custom actions
  resources :leads do
    member do
      post :qualify
      post :contact
      post :convert
    end

    collection do
      post :bulk_action
      get :analytics
      get :export
    end
  end

  # Webhook endpoints
  resources :webhooks, only: [:index] do
    collection do
      # Generic webhook receiver
      post ':platform/:integration_id', to: 'webhooks#receive', as: :receive
      get ':platform/:integration_id/verify', to: 'webhooks#verify', as: :verify

      # Platform-specific webhook endpoints
      post 'instagram/:integration_id', to: 'webhooks#instagram', as: :instagram
      post 'tiktok/:integration_id', to: 'webhooks#tiktok', as: :tiktok
      post 'salesforce/:integration_id', to: 'webhooks#salesforce', as: :salesforce
      post 'hubspot/:integration_id', to: 'webhooks#hubspot', as: :hubspot
      post 'pipedrive/:integration_id', to: 'webhooks#pipedrive', as: :pipedrive
    end
  end

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
