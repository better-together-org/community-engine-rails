# frozen_string_literal: true

module BetterTogether
  # Assigns a default community to records that belong to a platform.
  # Falls back to the host community when no community is explicitly set.
  module CommunityAssignable
    extend ActiveSupport::Concern

    included do
      before_validation :assign_host_community
    end

    private

    def assign_host_community
      return unless has_attribute?(:community_id)
      return if community.present?

      self.community ||= platform&.community
      self.community ||= BetterTogether::Community.find_by(host: true)
      self.community ||= host_platform_community
    end

    def host_platform_community
      id = BetterTogether::Platform.where(host: true).limit(1).pluck(:community_id).first
      return unless id

      BetterTogether::Community.find_by(id:)
    end
  end
end
