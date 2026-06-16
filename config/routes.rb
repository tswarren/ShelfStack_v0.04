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

  namespace :items do
    root to: "index#index"
    get "locked_out", to: "home#locked_out"
    get "search", to: redirect { |_params, request|
      query = request.query_parameters.slice("q", "page", "format_id", "department_id", "sub_department_id", "store_category_id", "include_inactive")
      query.present? ? "/items?#{query.to_query}" : "/items"
    }, as: :search
    get "item", to: "items#show", as: :item

    get "add_item", to: "add_item#show", as: :add_item
    post "add_item", to: "add_item#create"
    get "add_item/new", to: "add_item#new", as: :new_add_item

    get "ingram_import", to: "ingram_import#show", as: :ingram_import
    post "ingram_import/preview", to: "ingram_import#preview", as: :ingram_import_preview
    post "ingram_import", to: "ingram_import#create", as: :ingram_import_run

    get "bisac_subjects/search", to: "bisac_subject_searches#index", as: :bisac_subjects_search
    get "identifier_preview", to: "identifier_previews#show", as: :identifier_preview

    resources :catalog_items do
      member do
        patch :inactivate
        patch :reactivate
        post :add_identifier
        get :new_identifier
        post :generate_local_identifier
        patch :set_primary_identifier
        get :edit_identifier
        patch :update_identifier
        delete :destroy_identifier
      end
    end
    resources :products do
      member do
        patch :inactivate
        patch :reactivate
        patch :regenerate_name
      end
    end
    resources :product_variants do
      member do
        patch :inactivate
        patch :reactivate
        patch :regenerate_name
      end
    end
  end

  # Legacy redirects
  get "/catalog", to: redirect("/items")
  get "/catalog/*path", to: redirect { |params, _req| "/items/#{params[:path]}" }
  get "/products", to: redirect("/items")
  get "/products/*path", to: redirect { |params, _req| "/items/#{params[:path]}" }

  namespace :catalog do
    root to: redirect("/items")
    get "locked_out", to: redirect("/items/locked_out")
  end

  namespace :products do
    root to: redirect("/items")
    get "locked_out", to: redirect("/items/locked_out")
  end

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
    resources :sub_departments do
      member do
        patch :inactivate
        patch :reactivate
      end
    end
    resources :category_schemes do
      resources :category_nodes do
        member do
          patch :inactivate
          patch :reactivate
        end
      end
      member do
        patch :inactivate
        patch :reactivate
      end
    end
    resource :bisac_subjects, only: %i[show] do
      post :import, on: :member
    end
    resources :formats do
      member do
        patch :inactivate
        patch :reactivate
      end
    end
    resources :product_conditions do
      member do
        patch :inactivate
        patch :reactivate
      end
    end
    resources :display_locations do
      member do
        patch :inactivate
        patch :reactivate
      end
    end
    resources :store_display_locations do
      member do
        patch :inactivate
        patch :reactivate
      end
    end
    resources :vendors do
      member do
        patch :inactivate
        patch :reactivate
      end
    end
    resources :inventory_reason_codes do
      member do
        patch :inactivate
        patch :reactivate
      end
    end
    resources :inventory_locations do
      member do
        patch :inactivate
        patch :reactivate
      end
    end
  end

  namespace :inventory do
    root to: "balances#index"
    get "locked_out", to: "home#locked_out"
    get "negative", to: "negative_exceptions#index"
    get "enterprise", to: "enterprise#index"
    resources :variants, only: %i[show]
    resource :variant_lookup, only: %i[show]
    resources :adjustments do
      member do
        patch :post, action: :post
        patch :cancel
      end
    end
    resource :admin, only: %i[show], controller: "admin" do
      post :rebuild_balances
      post :integrity_check
    end
  end
end
