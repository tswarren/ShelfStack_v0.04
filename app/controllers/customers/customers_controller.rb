# frozen_string_literal: true

module Customers
  class CustomersController < BaseController
    before_action :set_customer, only: %i[show edit update inactivate reactivate]
    before_action -> { authorize!("customers.access") }, only: %i[index show]
    before_action -> { authorize!("customers.create") }, only: %i[new create]
    before_action -> { authorize!("customers.update") }, only: %i[edit update]
    before_action -> { authorize!("customers.inactivate") }, only: :inactivate
    before_action -> { authorize!("customers.reactivate") }, only: :reactivate

    def index
      @customers = Customer.active_records.order(:display_name)
      @customers = @customers.where("display_name ILIKE ?", "%#{params[:q]}%") if params[:q].present?
    end

    def show
      @customer_requests = @customer.customer_requests.where(store: customers_store).order(created_at: :desc).limit(20)
      @contact_events = CustomerContactEvent.where(customer: @customer).order(occurred_at: :desc).limit(20)
      @audit_events = AuditEvent.for_auditable(@customer).limit(20)
      @profile_presenter = Customers::ProfilePresenter.build(
        customer: @customer,
        store: customers_store,
        user: current_user
      )
    end

    def new
      @customer = Customer.new(home_store: customers_store)
      @return_to = safe_return_path(params[:return_to])
    end

    def create
      @customer = Customer.new(customer_params)
      @return_to = safe_return_path(params[:return_to])
      if @customer.save
        record_audit!("customer.created", @customer)
        redirect_after_create!
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @customer.update(customer_params)
        record_audit!("customer.updated", @customer)
        redirect_to customers_customer_path(@customer), notice: "Customer updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def inactivate
      @customer.inactivate!
      record_audit!("customer.inactivated", @customer)
      redirect_to customers_customers_path, notice: "Customer inactivated."
    end

    def reactivate
      @customer.reactivate!
      record_audit!("customer.reactivated", @customer)
      redirect_to customers_customer_path(@customer), notice: "Customer reactivated."
    end

    private

    def set_customer
      @customer = Customer.find(params[:id])
    end

    def customer_params
      params.require(:customer).permit(
        :display_name, :first_name, :last_name,
        :address_line1, :address_line2, :city, :region_code, :postal_code, :country_code,
        :email, :phone, :preferred_contact_method, :notes, :home_store_id
      )
    end

    def redirect_after_create!
      if @return_to.present?
        redirect_to customer_return_url(@return_to, @customer), notice: "Customer created."
      else
        redirect_to customers_customer_path(@customer), notice: "Customer created."
      end
    end

    def customer_return_url(base_path, customer)
      uri = URI.parse(base_path)
      query = Rack::Utils.parse_nested_query(uri.query.to_s)
      query["customer_id"] = customer.id.to_s
      uri.query = query.to_query
      uri.to_s
    end

    def safe_return_path(path)
      return nil if path.blank?

      uri = URI.parse(path)
      return nil unless uri.host.nil? || uri.host == request.host
      return nil unless uri.path.start_with?("/customers", "/buybacks")

      path
    rescue URI::InvalidURIError
      nil
    end
  end
end
