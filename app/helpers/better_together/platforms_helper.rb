# frozen_string_literal: true

module BetterTogether
  module PlatformsHelper # rubocop:todo Style/Documentation
    def invitation_token_expires_at
      session[:platform_invitation_expires_at].to_datetime.to_i
    end
  end
end
