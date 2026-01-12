# frozen_string_literal: true

module BetterTogether
  # Represents a user who signed up via OAuth (GitHub, etc.) and hasn't set a password yet
  # Once they set a password, they are converted to a regular User
  class OauthUser < ::BetterTogether.user_class
    # Override to allow password setting without current_password
    def update_with_password(params)
      if params[:password].present?
        # OAuth user setting password - convert to regular User and update
        convert_to_regular_user_with_password(params)
      else
        super
      end
    end

    # Override to not require password for OAuth-only users
    def password_required?(attributes = nil)
      return false if attributes&.key?(:password)

      super()
    end

    private

    # Convert OAuth user to regular User type when they set a password
    def convert_to_regular_user_with_password(params)
      params.delete(:current_password)

      # Change type to regular User
      self.type = nil

      # Update password
      update(params)
    end
  end
end
