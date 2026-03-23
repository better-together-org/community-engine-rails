# frozen_string_literal: true

module BetterTogether
  # Membership display helpers for Platform.
  module PlatformMembershipDisplay
    extend ActiveSupport::Concern

    MEMBERSHIP_INCLUDES = [
      { member: [
        :string_translations,
        :text_translations,
        { profile_image_attachment: { blob: { variant_records: [], preview_image_attachment: { blob: [] } } } }
      ] },
      { role: %i[string_translations text_translations] }
    ].freeze

    # Efficiently load platform memberships with all necessary associations
    # to prevent N+1 queries in views
    def memberships_with_associations
      person_platform_memberships.includes(*MEMBERSHIP_INCLUDES)
    end
  end
end
