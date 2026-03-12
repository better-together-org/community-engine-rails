# frozen_string_literal: true

module BetterTogether
  class PlatformConnectionsController < ResourceController
    def index
      @platform_connections = resource_collection
    end

    def show; end

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

    private

    def platform_connection_params
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
