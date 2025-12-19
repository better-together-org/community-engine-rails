# frozen_string_literal: true

module BetterTogether
  # Allows for CRUD operations for roles
  class RolesController < FriendlyResourceController
    before_action :set_role, only: %i[show edit update destroy]

    # GET /roles
    def index
      # Assuming Role class is under the same namespace for consistency
      authorize resource_class # Add this to authorize action
      @roles = policy_scope(resource_class.with_translations)
               .includes(:resource_permissions)
               .order(:resource_type, :position, :identifier)
      @roles_by_resource_type = @roles.group_by(&:resource_type)
      @available_view_types = %w[card table]
      @view_type = view_preference('roles_index', default: 'card', allowed: @available_view_types)
    end

    # GET /roles/1
    def show
      authorize @role # Ensure you authorize each action
    end

    # GET /roles/new
    def new
      @role = resource_class.new
      authorize @role
    end

    # GET /roles/1/edit
    def edit
      authorize @role
    end

    # POST /roles
    def create # rubocop:todo Metrics/MethodLength
      @role = resource_class.new(role_params)
      authorize @role # Add authorization check

      if @role.save
        redirect_to @role, only_path: true,
                           notice: t('flash.generic.created', resource: t('resources.role'))
      else
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.update(
              'form_errors',
              partial: 'layouts/better_together/errors',
              locals: { object: @role }
            )
          end
          format.html { render :new, status: :unprocessable_content }
        end
      end
    end

    # PATCH/PUT /roles/1
    def update # rubocop:todo Metrics/MethodLength
      authorize @role # Add authorization check

      if @role.update(role_params)
        redirect_to @role, only_path: true,
                           notice: t('flash.generic.updated', resource: t('resources.role')),
                           status: :see_other
      else
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.update(
              'form_errors',
              partial: 'layouts/better_together/errors',
              locals: { object: @role }
            )
          end
          format.html { render :edit, status: :unprocessable_content }
        end
      end
    end

    # DELETE /roles/1
    def destroy
      authorize @role # Add authorization check
      @role.destroy
      redirect_to roles_url, notice: t('flash.generic.destroyed', resource: t('resources.role')),
                             status: :see_other
    end

    private

    # Use callbacks to share common setup or constraints between actions.
    def set_role
      @role = set_resource_instance
    end

    def resource_class
      ::BetterTogether::Role
    end

    # Only allow a list of trusted parameters through.
    def role_params
      params.require(:role).permit(:name, :description)
    end
  end
end
