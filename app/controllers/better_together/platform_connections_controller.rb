# frozen_string_literal: true

module BetterTogether
  # Manages platform-to-platform federation connections, including create,
  # approve, suspend, and policy configuration.
  class PlatformConnectionsController < ResourceController
    before_action :set_connection_for_transition, only: %i[approve suspend]

    def index
      @platform_connections = resource_collection
    end

    def show; end

    def new
      @platform_connection = resource_class.new
      authorize @platform_connection
    end

    def create
      @platform_connection = resource_class.new(platform_connection_create_params)
      authorize @platform_connection

      if @platform_connection.save
        redirect_to @platform_connection,
                    notice: t('flash.generic.created', resource: 'Platform connection'),
                    status: :see_other
      else
        render :new, status: :unprocessable_content
      end
    rescue Pundit::NotAuthorizedError
      render_not_found
    end

    def edit; end

    def update
      if resource_instance.update(platform_connection_params)
        redirect_to resource_instance,
                    notice: t('flash.generic.updated', resource: 'Platform connection'),
                    status: :see_other
      else
        render :edit, status: :unprocessable_content
      end
    end

    def approve
      authorize @platform_connection

      if @platform_connection.pending? || @platform_connection.suspended?
        @platform_connection.update!(status: :active)
        redirect_to @platform_connection, notice: 'Connection approved and set to active.', status: :see_other
      else
        redirect_to @platform_connection,
                    alert: "Cannot approve a connection with status '#{@platform_connection.status}'.",
                    status: :see_other
      end
    rescue Pundit::NotAuthorizedError
      render_not_found
    end

    def suspend
      authorize @platform_connection

      if @platform_connection.active?
        @platform_connection.update!(status: :suspended)
        redirect_to @platform_connection, notice: 'Connection suspended.', status: :see_other
      else
        redirect_to @platform_connection,
                    alert: "Cannot suspend a connection with status '#{@platform_connection.status}'.",
                    status: :see_other
      end
    rescue Pundit::NotAuthorizedError
      render_not_found
    end

    private

    def set_connection_for_transition
      @platform_connection = resource_class.find(params[:id])
    end

    def platform_connection_create_params
      params.require(:platform_connection).permit(
        :source_platform_id,
        :target_platform_id,
        :connection_kind
      )
    end

    def platform_connection_params # rubocop:disable Metrics/MethodLength
      params.require(:platform_connection).permit(
        :status,
        :connection_kind,
        :content_sharing_policy,
        :federation_auth_policy,
        :content_sharing_enabled,
        :federation_auth_enabled,
        :share_posts,
        :share_pages,
        :share_events,
        :allow_identity_scope,
        :allow_profile_read_scope,
        :allow_content_read_scope,
        :allow_linked_content_read_scope,
        :allow_content_write_scope
      )
    end

    def resource_class
      ::BetterTogether::PlatformConnection
    end

    def resource_collection
      @resources ||= policy_scope(resource_class).includes(:source_platform, :target_platform)

      instance_variable_set("@#{resource_name(plural: true)}", @resources)
    end
  end
end
