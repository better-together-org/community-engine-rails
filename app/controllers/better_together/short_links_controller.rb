# frozen_string_literal: true

module BetterTogether
  class ShortLinksController < ResourceController # rubocop:todo Style/Documentation
    LINKABLE_TYPES = %w[
      BetterTogether::Page
      BetterTogether::Event
      BetterTogether::Community
      BetterTogether::Post
    ].freeze

    skip_before_action :authenticate_user!, only: [:ensure], raise: false
    rescue_from ActionController::BadRequest, with: :render_bad_request
    rescue_from Pundit::NotAuthorizedError, with: :render_forbidden

    def ensure
      linkable = resolve_linkable
      authorize linkable, :show?
      short_link = linkable.ensure_short_link!
      render turbo_stream: turbo_stream.replace(
        "sl-#{ActionView::RecordIdentifier.dom_id(linkable)}",
        partial: 'better_together/short_links/share_link_button',
        locals: { shareable: linkable, short_link: short_link }
      )
    end

    private

    def resource_class
      ShortLink
    end

    def resource_collection
      @resources ||= policy_scope(resource_class)
                     .where(platform: Current.platform)
                     .order(created_at: :desc)

      @short_links = @resources
    end

    def render_bad_request
      head :bad_request
    end

    def render_forbidden
      head :forbidden
    end

    def resolve_linkable
      type = params.require(:linkable_type)
      raise ActionController::BadRequest unless LINKABLE_TYPES.include?(type)

      klass = type.constantize
      scope = klass.column_names.include?('platform_id') ? klass.where(platform: Current.platform) : klass
      scope.find(params.require(:linkable_id))
    end
  end
end
