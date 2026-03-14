# frozen_string_literal: true

module BetterTogether
  # Manages platform-to-platform federation connections, including create,
  # approve, suspend, and policy configuration.
  class PlatformConnectionsController < ResourceController # rubocop:disable Metrics/ClassLength
    before_action :set_connection_for_transition, only: %i[approve suspend rotate_secret]

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
        redirect_to better_together.platform_connection_path(@platform_connection),
                    notice: t('flash.generic.created', resource: ::BetterTogether::PlatformConnection.model_name.human),
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
        redirect_to better_together.platform_connection_path(resource_instance),
                    notice: t('flash.generic.updated', resource: ::BetterTogether::PlatformConnection.model_name.human),
                    status: :see_other
      else
        render :edit, status: :unprocessable_content
      end
    end

    def approve
      authorize @platform_connection

      if @platform_connection.pending? || @platform_connection.suspended?
        @platform_connection.update!(status: :active)
        redirect_to better_together.platform_connection_path(@platform_connection),
                    notice: t('better_together.platform_connections.flash.approved'), status: :see_other
      else
        redirect_to better_together.platform_connection_path(@platform_connection),
                    alert: t('better_together.platform_connections.flash.cannot_approve',
                             status: t("better_together.enums.platform_connection.status.#{@platform_connection.status}")),
                    status: :see_other
      end
    rescue Pundit::NotAuthorizedError
      render_not_found
    end

    def suspend
      authorize @platform_connection

      if @platform_connection.active?
        @platform_connection.update!(status: :suspended)
        redirect_to better_together.platform_connection_path(@platform_connection),
                    notice: t('better_together.platform_connections.flash.suspended'), status: :see_other
      else
        redirect_to better_together.platform_connection_path(@platform_connection),
                    alert: t('better_together.platform_connections.flash.cannot_suspend',
                             status: t("better_together.enums.platform_connection.status.#{@platform_connection.status}")),
                    status: :see_other
      end
    rescue Pundit::NotAuthorizedError
      render_not_found
    end

    def rotate_secret
      authorize @platform_connection, :update?

      @platform_connection.rotate_oauth_client_secret!
      redirect_to better_together.platform_connection_path(@platform_connection),
                  notice: t('better_together.platform_connections.flash.secret_rotated'), status: :see_other
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
