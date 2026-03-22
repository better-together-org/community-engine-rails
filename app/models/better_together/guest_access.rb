# frozen_string_literal: true

module BetterTogether
  # Allows for platform managers to allow guest access to the platform
  class GuestAccess < PlatformInvitation
    def self.model_name
      ActiveModel::Name.new(self)
    end

    def registers_user?
      false
    end

    def url
      BetterTogether::Engine.routes.url_helpers.home_page_url(invitation_code: token, locale:)
    end
  end
end
