# frozen_string_literal: true

module BetterTogether
  # Allows for CRUD operations for roles
  class RolesController < ApplicationController
    before_action :set_role, only: %i[show edit update destroy]

    # GET /roles
    def index
      # Assuming Role class is under the same namespace for consistency
      authorize ::BetterTogether::Role # Add this to authorize action
      @roles = policy_scope(::BetterTogether::Role.with_translations) # Use Pundit's scope
    end

    # GET /roles/1
    def show
      authorize @role # Ensure you authorize each action
    end

    # GET /roles/new
    def new
      @role = ::BetterTogether::Role.new
      authorize @role
    end

    # GET /roles/1/edit
    def edit
      authorize @role
    end

    # POST /roles
    def create
      @role = ::BetterTogether::Role.new(role_params)
      authorize @role # Add authorization check

      if @role.save
        redirect_to @role, only_path: true, notice: 'Role was successfully created.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /roles/1
    def update
      authorize @role # Add authorization check

      if @role.update(role_params)
        redirect_to @role, only_path: true, notice: 'Role was successfully updated.', status: :see_other
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /roles/1
    def destroy
      authorize @role # Add authorization check
      @role.destroy
      redirect_to roles_url, notice: 'Role was successfully destroyed.', status: :see_other
    end

    private

    # Use callbacks to share common setup or constraints between actions.
    def set_role
      @role = ::BetterTogether::Role.friendly.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def role_params
      params.require(:role).permit(:name, :description)
    end
  end
end
