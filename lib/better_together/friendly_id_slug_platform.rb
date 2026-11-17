# frozen_string_literal: true

module BetterTogether
  # Gives FriendlyId::Slug rows the platform of the record they belong to, so slug history is
  # unique per platform. A row that takes over a slug evicts other records' stale history rows
  # for the same platform, type, slug and locale; the finder already prefers the current owner.
  module FriendlyIdSlugPlatform
    extend ActiveSupport::Concern

    included do
      before_validation :copy_platform_from_sluggable
      before_create :evict_stale_history_for_same_slug
    end

    private

    def copy_platform_from_sluggable
      return unless has_attribute?(:platform_id) && platform_id.blank?

      owner = sluggable
      self.platform_id = owner.platform_id if owner&.has_attribute?(:platform_id)
    end

    def evict_stale_history_for_same_slug
      return unless has_attribute?(:platform_id)

      self.class.unscoped
          .where(sluggable_type:, slug:, locale:, platform_id:)
          .where.not(sluggable_id:)
          .delete_all
    end
  end
end
