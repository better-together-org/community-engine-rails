# frozen_string_literal: true

module BetterTogether
  # Represents a devise-powered user model 
  module DeviseUser
    extend ActiveSupport::Concern

    included do
      include FriendlySlug
  
      slugged :email_username, slug_column: :username

      validates :email, presence: true, uniqueness: { case_sensitive: false }
      validates :username, presence: true, uniqueness: { case_sensitive: false }

      def email_username
        email ? email.split('@').first : ''
      end

      # TODO: address the confirmation and password reset email modifications for api users when the API is under active development and full use.
      # override devise method to include additional info as opts hash
      def send_confirmation_instructions(opts = {})
        generate_confirmation_token! unless @raw_confirmation_token

        opts[:to] = unconfirmed_email if pending_reconfirmation?
        opts[:confirmation_url] ||= BetterTogether.user_confirmation_url
        opts[:confirmation_url] += "?confirmation_token=#{@raw_confirmation_token}"

        opts[:person_name] = person&.name || unconfirmed_email

        send_devise_notification(:confirmation_instructions, @raw_confirmation_token, opts)
      end

      # # override devise method to include additional info as opts hash
      def send_reset_password_instructions(opts = {})
        token = set_reset_password_token

        opts[:new_password_url] ||= BetterTogether.new_user_password_url
        opts[:new_password_url] += "?reset_password_token=#{token}"

        send_devise_notification(:reset_password_instructions, token, opts)
        token
      end
    end
  end
end
