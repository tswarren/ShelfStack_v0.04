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

  namespace :reports do
    root to: "index#show"
    get "register_summary", to: "register_summary#show"
    get "cash_drawer", to: "cash_drawer#show"
    get "sales_summary", to: "sales_summary#show"
    get "sales", to: "sales#show"
    get "returns", to: "returns#show"
    get "operational_margin", to: "operational_margin#show"
    get "tax_collected", to: "tax_collected#show"
    get "discount_summary", to: "discount_summary#show"
    get "buyback_summary", to: "buyback_summary#show"
    get "stored_value", to: "stored_value#show"
    get "inventory_value", to: "inventory_value#show"
    get "purchasing_summary", to: "purchasing_summary#show"
    get "customer_requests", to: "customer_requests#show"
    get "shells/reconciliation", to: redirect("/reports/tax_collected")
    get "shells/queue", to: redirect("/reports/customer_requests")
  end

  namespace :items do
    root to: "index#index"
    get "locked_out", to: "home#locked_out"
    get "search", to: redirect { |_params, request|
      query = request.query_parameters.slice("q", "page", "format_id", "department_id", "sub_department_id", "store_category_id", "include_inactive")
      query.present? ? "/items?#{query.to_query}" : "/items"
    }, as: :search
    get "item", to: "items#show", as: :item
    get "item/external_metadata", to: "external_metadata#show", as: :item_external_metadata
    post "customer_demand", to: "customer_demand_actions#create", as: :customer_demand

    get "add_item", to: "add_item#show", as: :add_item
    post "add_item", to: "add_item#create"
    get "add_item/new", to: "add_item#new", as: :new_add_item

    get "ingram_import", to: "ingram_import#show", as: :ingram_import
    post "ingram_import/preview", to: "ingram_import#preview", as: :ingram_import_preview
    post "ingram_import", to: "ingram_import#create", as: :ingram_import_run

    get "identifier_preview", to: "identifier_previews#show", as: :identifier_preview

    post "external_lookup", to: "external_lookup#lookup", as: :external_lookup
    get "external_lookup/:id", to: "external_lookup#preview", as: :external_lookup_result
    post "external_lookup/:id/import", to: "external_lookup#import", as: :external_lookup_import

    get "bisac_subjects/search", to: "bisac_subject_searches#index", as: :bisac_subjects_search
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
      resources :product_vendors, only: %i[new create edit update]
    end
    resources :product_variants do
      member do
        patch :inactivate
        patch :reactivate
        patch :regenerate_name
      end
      resources :product_variant_vendors, only: %i[new create edit update]
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
    get "external_data_sources", to: "external_data_sources#index", as: :external_data_sources
    post "external_data_sources/:source_key/health_check", to: "external_data_sources#health_check", as: :external_data_source_health_check
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
    resources :product_vendors do
      member do
        patch :inactivate
        patch :reactivate
      end
    end
    resources :product_variant_vendors do
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
    resources :stored_value_reason_codes do
      member do
        patch :inactivate
        patch :reactivate
      end
    end
    resources :discount_reasons do
      member do
        patch :inactivate
        patch :reactivate
      end
    end
    resources :tax_exception_reasons do
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

  namespace :customers do
    root to: "home#show"
    get "locked_out", to: "home#locked_out"
    resource :customer_lookup, only: %i[show]
    resource :variant_lookup, only: %i[show]
    resources :customers do
      member do
        patch :inactivate
        patch :reactivate
      end
      resources :contact_events, only: %i[create]
    end
    resources :customer_requests do
      member do
        patch :cancel
        patch :mark_unfillable
        post :match_variant
        patch :update_line_type
        post :mark_awaiting_response
        post :create_special_order
        post :create_hold
        post :release_hold
        post :attach_special_order
        post :build_purchase_order_from_special_order
        post :record_contact
      end
    end
    resources :stored_value_accounts do
      collection do
        get :lookup
      end
      member do
        patch :suspend
        patch :close
        patch :reactivate
      end
      resources :identifiers, controller: "stored_value_identifiers", only: %i[create] do
        member do
          post :reveal
          post :replace
          patch :deactivate
        end
      end
      resource :operations, controller: "stored_value_account_operations", only: [] do
        post :issue
        post :adjust
        post :transfer
        post :void_entry
      end
    end
    resources :stored_value_reports, only: %i[index]
  end

  namespace :buybacks do
    root to: "home#show"
    get "locked_out", to: "home#locked_out"
    resources :reports, only: %i[index]
    resources :sessions, only: %i[new create show update] do
      member do
        patch :complete
        patch :cancel
        patch :void
        get :receipt
        get :trade_credit_slip, to: "trade_credit_issuance_slips#show"
        post :print_trade_credit_slip, to: "trade_credit_issuance_slips#print"
        patch :save_proposal
        patch :open_decision
        get :print_proposal
        patch :accept_all_lines
        patch :decline_all_lines
        patch :donate_declined_lines
      end
      resources :lines, only: %i[create update destroy] do
        member do
          get :detail
          post :reject
          post :resolve
          post :select_variant
          post :intake
          patch :price_override
          patch :offer_override
          patch :update_proposal
          patch :record_decision
        end
      end
    end
  end

  namespace :orders do
    root to: "home#show"
    get "locked_out", to: "home#locked_out"
    resource :variant_lookup, only: %i[show]
    resource :line_lookup, only: %i[show]
    resources :purchase_requests do
      member do
        patch :cancel
        get :build_purchase_order
        post :create_purchase_order
      end
    end
    resources :purchase_orders do
      collection do
        get :from_tbo
        post :create_from_tbo
      end
      member do
        patch :submit
        patch :cancel
        patch :close
        post :receive
      end
    end
    resources :receipts do
      member do
        patch :post, action: :post
        patch :cancel
      end
    end
    resources :returns_to_vendor do
      member do
        patch :post, action: :post
        patch :cancel
      end
    end
  end

  namespace :pos do
    root to: "home#show"
    get "locked_out", to: "home#locked_out"
    resource :line_lookup, only: %i[show]
    resource :return_lookup, only: %i[show]
    resource :stored_value_lookup, only: %i[show]
    resource :stored_value_balance, only: %i[show], controller: "stored_value_balance"
    resource :pickup_lookup, only: %i[create]
    resources :authorizations, only: %i[create]
    resources :register_sessions, only: %i[new create show] do
      member do
        patch :close
        patch :force_close
      end
      resources :cash_movements, only: %i[create]
    end
    resources :transactions do
      member do
        patch :complete
        patch :suspend
        patch :resume
        patch :void
        patch :cancel
        post :add_line
        post :add_reservation_line
        post :add_return_line
        post :add_open_ring_line
        post :add_gift_card_sale_line
        patch :update_gift_card_sale_line
        patch :update_line
        post :apply_line_discount
        post :apply_transaction_discount
        delete :void_discount_application
        post :apply_tax_exemption
        delete :void_tax_exemption
        post :apply_line_tax_override
        delete :void_line_tax_override
        delete :remove_line
        patch :sync_tenders
        post :readiness_preview
        post :route_command
      end
    end
    resources :receipts, only: %i[show] do
      member do
        patch :print
      end
    end
    resources :stored_value_issuance_slips, only: %i[show], path: "stored_value_issuance_slips" do
      member do
        patch :print
      end
    end
    resources :reports, only: %i[index] do
      collection do
        get :sales
        get :returns
        get :drawer
        get :summary
        get :register_summary
        get :operational_margin
      end
    end
  end

  if Rails.env.test?
    namespace :test do
      get "interaction_shell", to: "interaction_shell#show"
      post "interaction_shell/turbo_update", to: "interaction_shell#turbo_update", as: :interaction_shell_turbo_update
      post "interaction_shell/append_toast", to: "interaction_shell#append_toast", as: :interaction_shell_append_toast
      post "interaction_shell/replace_drawer", to: "interaction_shell#replace_drawer", as: :interaction_shell_replace_drawer
    end
  end
end
