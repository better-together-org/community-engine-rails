# frozen_string_literal: true

module BetterTogether
  # Admin CRUD for platform storage configurations.
  # Nested under platforms — all actions are scoped to a specific platform.
  # Requires manage_platform permission (enforced via route constraint + Pundit).
  class StorageConfigurationsController < ApplicationController
    before_action :set_platform
    before_action :set_storage_configuration, only: %i[show edit update destroy activate test_connection]
    after_action :verify_authorized

    # GET /host/platforms/:platform_id/storage_configurations
    def index
      authorize @platform.storage_configurations.build
      @storage_configurations = @platform.storage_configurations.order(created_at: :asc)
      @resolver = StorageResolver.new(@platform)
    end

    # GET /host/platforms/:platform_id/storage_configurations/new
    def new
      @storage_configuration = @platform.storage_configurations.build(service_type: 'local')
      authorize @storage_configuration
    end

    # GET /host/platforms/:platform_id/storage_configurations/:id/edit
    def edit
      authorize @storage_configuration
    end

    # POST /host/platforms/:platform_id/storage_configurations
    def create
      @storage_configuration = @platform.storage_configurations.build(storage_configuration_params)
      authorize @storage_configuration

      if @storage_configuration.save
        redirect_to platform_storage_configurations_path(@platform),
                    status: :see_other,
                    notice: t('better_together.storage_configurations.created')
      else
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /host/platforms/:platform_id/storage_configurations/:id
    def update
      authorize @storage_configuration

      if @storage_configuration.update(update_params)
        redirect_to platform_storage_configurations_path(@platform),
                    status: :see_other,
                    notice: t('better_together.storage_configurations.updated')
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /host/platforms/:platform_id/storage_configurations/:id
    def destroy
      authorize @storage_configuration

      if @platform.storage_configuration_id == @storage_configuration.id
        redirect_to platform_storage_configurations_path(@platform),
                    status: :see_other,
                    alert: t('better_together.storage_configurations.cannot_destroy_active')
        return
      end

      @storage_configuration.destroy
      redirect_to platform_storage_configurations_path(@platform),
                  status: :see_other,
                  notice: t('better_together.storage_configurations.destroyed')
    end

    # PUT /host/platforms/:platform_id/storage_configurations/:id/activate
    # Sets this configuration as the platform's primary/active storage.
    def activate
      authorize @storage_configuration, :activate?

      @platform.update!(storage_configuration_id: @storage_configuration.id)

      # Every platform's uploads route to its own service. Only the host also sets the process
      # default, which jobs and console blobs without a platform use.
      StorageResolver.new(@platform.reload).register!
      key = @platform.host? ? 'activated_with_restart' : 'activated_for_platform'
      rebind_active_storage_service(@platform) if @platform.host?
      notice = t("better_together.storage_configurations.#{key}", name: @storage_configuration.name)

      redirect_to platform_storage_configurations_path(@platform),
                  status: :see_other,
                  notice: notice
    end

    # POST /host/platforms/:platform_id/storage_configurations/:id/test_connection
    # Writes, reads and deletes a probe object and records the outcome on the configuration.
    def test_connection
      authorize @storage_configuration, :test_connection?

      result = @storage_configuration.test_connection!
      key = result.ok? ? 'connection_ok' : 'connection_failed'
      message = t("better_together.storage_configurations.#{key}",
                  name: @storage_configuration.name, message: result.message)
      redirect_to platform_storage_configurations_path(@platform), status: :see_other,
                                                                   (result.ok? ? :notice : :alert) => message
    end

    private

    def set_platform
      # Routes use platform.to_param which returns the FriendlyId slug.
      # Use Platform.friendly.find so FriendlyId + Mobility handle the i18n lookup.
      @platform = Platform.friendly.find(params[:platform_id])
    end

    def set_storage_configuration
      @storage_configuration = @platform.storage_configurations.find(params[:id])
    end

    def storage_configuration_params
      params.require(:storage_configuration).permit(
        :name, :service_type, :endpoint, :bucket, :region, :access_key_id, :secret_access_key
      )
    end

    # On update, strip blank credential fields so existing encrypted values are preserved.
    # The form hints tell users "leave blank to keep the existing value".
    def update_params
      p = storage_configuration_params
      p.delete(:access_key_id) if p[:access_key_id].blank?
      p.delete(:secret_access_key) if p[:secret_access_key].blank?
      p
    end

    # Rebinds the process default for the host platform so new uploads without a platform use it
    # immediately. Other processes pick the change up through the registry's periodic refresh.
    def rebind_active_storage_service(platform)
      StorageResolver.new(platform).rebind_default!
    end
  end
end
