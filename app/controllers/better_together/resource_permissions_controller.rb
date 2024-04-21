module BetterTogether
  class ResourcePermissionsController < ApplicationController
    before_action :set_resource_permission, only: %i[ show edit update destroy ]

    # GET /resource_permissions
    def index
      @resource_permissions = ResourcePermission.all
    end

    # GET /resource_permissions/1
    def show
    end

    # GET /resource_permissions/new
    def new
      @resource_permission = ResourcePermission.new
    end

    # GET /resource_permissions/1/edit
    def edit
    end

    # POST /resource_permissions
    def create
      @resource_permission = ResourcePermission.new(resource_permission_params)

      if @resource_permission.save
        redirect_to @resource_permission, notice: "Resource permission was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /resource_permissions/1
    def update
      if @resource_permission.update(resource_permission_params)
        redirect_to @resource_permission, notice: "Resource permission was successfully updated.", status: :see_other
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /resource_permissions/1
    def destroy
      @resource_permission.destroy
      redirect_to resource_permissions_url, notice: "Resource permission was successfully destroyed.", status: :see_other
    end

    private
      # Use callbacks to share common setup or constraints between actions.
      def set_resource_permission
        @resource_permission = ResourcePermission.find(params[:id])
      end

      # Only allow a list of trusted parameters through.
      def resource_permission_params
        params.require(:resource_permission).permit(:action, :resource_class)
      end
  end
end
