# frozen_string_literal: true

module BetterTogether
  # Represents a devise-powered user model 
  module DeviseUser
    extend ActiveSupport::Concern

    included do
      # override devise method to include additional info as opts hash
      def send_confirmation_instructions(opts = {})
        generate_confirmation_token! unless @raw_confirmation_token

        opts[:to] = unconfirmed_email if pending_reconfirmation?
        opts[:confirmation_url] ||= BetterTogether.default_user_confirmation_url
        opts[:confirmation_url] += "?confirmation_token=#{@raw_confirmation_token}"

        send_devise_notification(:confirmation_instructions, @raw_confirmation_token, opts)
      end

      # override devise method to include additional info as opts hash
      def send_reset_password_instructions(opts = {})
        token = set_reset_password_token

        opts[:new_password_url] ||= BetterTogether.default_user_new_password_url

        opts[:new_password_url] += "?reset_password_token=#{token}"

        send_devise_notification(:reset_password_instructions, token, opts)
        token
      end
    end
  end
end
