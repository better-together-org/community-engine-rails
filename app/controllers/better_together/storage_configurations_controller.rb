# frozen_string_literal: true

module BetterTogether
  # Admin CRUD for platform storage configurations.
  # Nested under platforms — all actions are scoped to a specific platform.
  # Requires manage_platform permission (enforced via route constraint + Pundit).
  class StorageConfigurationsController < ApplicationController
    before_action :set_platform
    before_action :set_storage_configuration, only: %i[show edit update destroy activate]
    after_action :verify_authorized

    # GET /host/platforms/:platform_id/storage_configurations
    def index
      authorize StorageConfiguration
      @storage_configurations = @platform.storage_configurations.order(created_at: :asc)
      @resolver = StorageResolver.new(@platform)
    end

    # GET /host/platforms/:platform_id/storage_configurations/new
    def new
      authorize StorageConfiguration
      @storage_configuration = @platform.storage_configurations.build(service_type: 'local')
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
                    notice: t('better_together.storage_configurations.created')
      else
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /host/platforms/:platform_id/storage_configurations/:id
    def update
      authorize @storage_configuration

      if @storage_configuration.update(storage_configuration_params)
        redirect_to platform_storage_configurations_path(@platform),
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
                    alert: t('better_together.storage_configurations.cannot_destroy_active')
        return
      end

      @storage_configuration.destroy
      redirect_to platform_storage_configurations_path(@platform),
                  notice: t('better_together.storage_configurations.destroyed')
    end

    # PUT /host/platforms/:platform_id/storage_configurations/:id/activate
    # Sets this configuration as the platform's primary/active storage.
    def activate
      authorize @storage_configuration, :update?

      @platform.update!(storage_configuration_id: @storage_configuration.id)
      redirect_to platform_storage_configurations_path(@platform),
                  notice: t('better_together.storage_configurations.activated',
                            name: @storage_configuration.name)
    end

    private

    def set_platform
      @platform = Platform.find(params[:platform_id])
    end

    def set_storage_configuration
      @storage_configuration = @platform.storage_configurations.find(params[:id])
    end

    def storage_configuration_params
      params.require(:storage_configuration).permit(
        :name, :service_type, :endpoint, :bucket, :region, :access_key_id, :secret_access_key
      )
    end
  end
end
