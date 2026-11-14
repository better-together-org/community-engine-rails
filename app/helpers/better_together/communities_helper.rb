# frozen_string_literal: true

module BetterTogether
  # Helpers for rendering community references on community-scoped records.
  module CommunitiesHelper
    # Renders a linked community chip. Omitted when the viewer cannot see the
    # community, or when the page is already scoped to that community.
    def community_chip(community, hide_current: true)
      return if community.blank?
      return if hide_current && browsing_community?(community)
      return unless community_chip_visible?(community)

      render 'better_together/shared/community_chip', community:
    end

    private

    def browsing_community?(community)
      scoped = params[:community_id].to_s
      scoped.present? && [community.id, community.slug, community.identifier].map(&:to_s).include?(scoped)
    end

    # Memoized per request so a page of cards runs one policy check per community.
    def community_chip_visible?(community)
      @community_chip_visibility ||= {}
      return @community_chip_visibility[community.id] if @community_chip_visibility.key?(community.id)

      @community_chip_visibility[community.id] = policy(community).show?
    end
  end
end
