# frozen_string_literal: true

module BetterTogether
  # Keeps a record's auto-created primary community private, so it never appears in a communities directory.
  # Include after PrimaryCommunity#has_community. The community is created at the record's own privacy (the
  # privacy ceiling check needs that), then set private directly once the record is saved.
  module PrivatePrimaryCommunity
    extend ActiveSupport::Concern

    included do
      after_save :keep_primary_community_private
    end

    private

    def keep_primary_community_private
      community.update_columns(privacy: 'private') if community && !community.privacy_private?
    end
  end
end
