# frozen_string_literal: true

module BetterTogether
  module PlatformsHelper # rubocop:todo Style/Documentation
    # Get invitation token expiry timestamp for any invitation type
    # Checks all invitation types (platform, community, event) and returns the first one found
    def invitation_token_expires_at
      invitation_types = %w[platform community event]

      invitation_types.each do |type|
        expires_key = :"#{type}_invitation_expires_at"
        next unless session[expires_key].present?

        time = session[expires_key]
        # Convert to Time object if it's a string, then get Unix timestamp
        time = Time.parse(time) if time.is_a?(String)
        return time.to_i
      end

      nil
    end

    # Get the active invitation token for any invitation type
    def active_invitation_token
      invitation_types = %w[platform community event]

      invitation_types.each do |type|
        token_key = :"#{type}_invitation_token"
        return session[token_key] if session[token_key].present?
      end

      nil
    end
  end
end
