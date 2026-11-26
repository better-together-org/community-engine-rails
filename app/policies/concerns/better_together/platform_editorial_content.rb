# frozen_string_literal: true

module BetterTogether
  # Separates the platform's own editorial content from content that belongs to
  # its communities and members. A platform manager operates the platform
  # (settings, member status, hide and suspend) and edits the platform's own
  # content, but does not read private or draft content that lives in a
  # community or belongs to a person unless a community permission or a
  # membership grants it.
  module PlatformEditorialContent
    # Communities whose content is the platform's own editorial content: the
    # current platform's community and the host community every platform
    # defaults new content into.
    def platform_editorial_community_ids
      @platform_editorial_community_ids ||= [
        PlatformRecordPolicy.resolve_current_platform&.community_id,
        BetterTogether::Platform.where(host: true).limit(1).pick(:community_id)
      ].compact.uniq
    end

    # Content with no community counts as editorial, matching how it was created. The
    # record's own platform community counts too.
    def platform_editorial_community?(community_id, record_platform = nil)
      community_id.nil? ||
        platform_editorial_community_ids.include?(community_id) ||
        record_platform&.community_id == community_id
    end
  end
end
