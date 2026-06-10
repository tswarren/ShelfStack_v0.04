Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  resource :password, only: %i[edit update], controller: "passwords"
  resource :pin, only: %i[edit update], controller: "pins"

  resource :workstation_assignment, only: %i[new create], controller: "workstation_assignments"

  get "session/unlock", to: "session_locks#show", as: :session_unlock
  post "session/unlock", to: "session_locks#create"
  post "session/lock", to: "session_locks#lock", as: :session_lock
  get "session/status", to: "session_status#show", as: :session_status

  root "dashboard#show"

  namespace :setup do
    root to: "home#show"
    get "locked_out", to: "home#locked_out"
    resources :users do
      member do
        patch :inactivate
        patch :reactivate
        patch :reset_password
        patch :clear_pin
        post :assign_role
        patch :remove_role
      end
    end
    resources :roles do
      member do
        patch :inactivate
        patch :reactivate
        patch :update_permissions
      end
    end
    resources :permissions, only: %i[index]
    resources :stores do
      member do
        patch :inactivate
        patch :reactivate
      end
    end
    resources :workstations do
      member do
        patch :inactivate
        patch :reactivate
      end
    end
    resources :audit_events, only: %i[index show]
    resources :tax_categories do
      member do
        patch :inactivate
        patch :reactivate
      end
    end
    resources :store_tax_rates do
      member do
        patch :inactivate
        patch :reactivate
      end
    end
    resources :store_tax_category_rates do
      member do
        patch :inactivate
        patch :reactivate
      end
    end
    resources :departments do
      member do
        patch :inactivate
        patch :reactivate
      end
    end
    resources :categories do
      member do
        patch :inactivate
        patch :reactivate
      end
    end
  end
end
