# frozen_string_literal: true

module BetterTogether
  # View helpers for membership request display
  module MembershipRequestsHelper
    STATUS_BADGE_MAP = {
      'open' => 'primary',
      'matched' => 'info',
      'fulfilled' => 'success',
      'closed' => 'secondary'
    }.freeze

    def membership_request_status_badge(status)
      STATUS_BADGE_MAP.fetch(status.to_s, 'secondary')
    end
  end
end
