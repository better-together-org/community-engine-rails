# frozen_string_literal: true

module BetterTogether
  # Represents a devise-powered user model
  module DeviseUser
    extend ActiveSupport::Concern

    included do # rubocop:todo Metrics/BlockLength
      include FriendlySlug

      slugged :email

      has_many :person_platform_integrations, dependent: :destroy

      validates :email, presence: true, uniqueness: { case_sensitive: false }

      # rubocop:todo Metrics/CyclomaticComplexity
      # rubocop:todo Metrics/MethodLength
      def self.from_omniauth(person_platform_integration:, auth:, current_user:) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        person_platform_integration = PersonPlatformIntegration.update_or_initialize(person_platform_integration, auth)

        return person_platform_integration.user if person_platform_integration.user.present?

        unless person_platform_integration.persisted?
          user = current_user.present? ? current_user : find_by(email: auth['info']['email'])

          if user.blank?
            user = new
            user.skip_confirmation!
            user.password = ::Devise.friendly_token[0, 20]
            user.attributes_from_auth(auth)

            person_attributes = {
              name: person_platform_integration.name || user.email.split('@').first || 'Unidentified Person',
              handle: person_platform_integration.handle || user.email.split('@').first
            }
            user.build_person(person_attributes)

            user.save
          end

          person_platform_integration.user = user
          person_platform_integration.person = user.person

          person_platform_integration.save
        end

        person_platform_integration.user
      end
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/CyclomaticComplexity

      def attributes_from_auth(auth)
        self.email = auth.info.email
      end

      def send_devise_notification(notification, *)
        devise_mailer.send(notification, self, *).deliver_later
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

      def send_devise_notification(notification, *args)
        devise_mailer.send(notification, self, *args).deliver_later
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
