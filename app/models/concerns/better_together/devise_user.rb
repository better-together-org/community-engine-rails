# frozen_string_literal: true

module BetterTogether
  # Represents a devise-powered user model
  module DeviseUser
    extend ActiveSupport::Concern

    included do
      include FriendlySlug

      slugged :email

      validates :email, presence: true, uniqueness: { case_sensitive: false }

      def send_devise_notification(notification, *)
        devise_mailer.send(notification, self, *).deliver_later
      end

      def self.from_omniauth(auth)
        find_or_create_by(provider: auth.provider, uid: auth.uid) do |user|
          user.email = auth.info.email
          user.password = Devise.friendly_token[0, 20]
          # user.name = auth.info.name   # assuming the user model has a name
          # user.image = auth.info.image # assuming the user model has an image
          # If you are using confirmable and the provider(s) you use validate emails,
          # uncomment the line below to skip the confirmation emails.
          # user.skip_confirmation!
        end
      end

      def self.new_with_session(params, session)
        super.tap do |user|
          if (data = session['devise.github_data'] && session['devise.github_data']['extra']['raw_info']) && user.email.blank?
            user.email = data['email']
          end
        end
      end

      # TODO: address the confirmation and password reset email modifications for api users when the API is under
      # active development and full use.
      # override devise method to include additional info as opts hash
      def send_confirmation_instructions(opts = {})
        generate_confirmation_token! unless @raw_confirmation_token

        opts[:to] = unconfirmed_email if pending_reconfirmation?
        opts[:confirmation_url] ||= ::BetterTogether.user_confirmation_url
        opts[:confirmation_url] += "?confirmation_token=#{@raw_confirmation_token}"

        opts[:person_name] = person&.name || unconfirmed_email

        send_devise_notification(:confirmation_instructions, @raw_confirmation_token, opts)
      end

      def send_devise_notification(notification, *)
        devise_mailer.send(notification, self, *).deliver_later
      end

      # # override devise method to include additional info as opts hash
      def send_reset_password_instructions(opts = {})
        token = set_reset_password_token

        opts[:new_password_url] ||= ::BetterTogether.new_user_password_url
        opts[:new_password_url] += "?reset_password_token=#{token}"

        send_devise_notification(:reset_password_instructions, token, opts)
        token
      end
    end
  end
end
