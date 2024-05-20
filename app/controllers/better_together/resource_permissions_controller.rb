# frozen_string_literal: true

module BetterTogether
  # Allows for CRUD operations for Resource Permissions
  class ResourcePermissionsController < ApplicationController
    before_action :set_resource_permission, only: %i[show edit update destroy]

    # GET /resource_permissions
    def index
      authorize ::BetterTogether::ResourcePermission
      @resource_permissions = policy_scope(::BetterTogether::ResourcePermission.with_translations)
    end

    # GET /resource_permissions/1
    def show
      authorize @resource_permission
    end

    # GET /resource_permissions/new
    def new
      @resource_permission = ::BetterTogether::ResourcePermission.new
      authorize @resource_permission
    end

    # GET /resource_permissions/1/edit
    def edit
      authorize @resource_permission
    end

    # POST /resource_permissions
    def create
      @resource_permission = ::BetterTogether::ResourcePermission.new(resource_permission_params)
      authorize @resource_permission

      if @resource_permission.save
        redirect_to @resource_permission, only_path: true, notice: 'Resource permission was successfully created.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /resource_permissions/1
    def update
      authorize @resource_permission

      if @resource_permission.update(resource_permission_params)
        redirect_to @resource_permission, only_path: true, notice: 'Resource permission was successfully updated.',
                                          status: :see_other
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /resource_permissions/1
    def destroy
      authorize @resource_permission
      @resource_permission.destroy
      redirect_to resource_permissions_url, notice: 'Resource permission was successfully destroyed.',
                                            status: :see_other
    end

    private

    # Use callbacks to share common setup or constraints between actions.
    def set_resource_permission
      @resource_permission = ::BetterTogether::ResourcePermission.friendly.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def resource_permission_params
      params.require(:resource_permission).permit(:action, :target, :resource_type)
    end
  end
end
