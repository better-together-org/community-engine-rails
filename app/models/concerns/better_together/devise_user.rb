# frozen_string_literal: true

module BetterTogether
  # Represents a devise-powered user model
  module DeviseUser
    extend ActiveSupport::Concern

    included do
      include FriendlySlug

      slugged :email

      has_many :person_platform_integrations, dependent: :destroy

      validates :email, presence: true, uniqueness: { case_sensitive: false }

      def self.from_omniauth(person_platform_integration:, auth:, current_user:)
        # PersonPlatformIntegration will automatically find the correct external OAuth platform
        person_platform_integration = PersonPlatformIntegration.update_or_initialize(person_platform_integration, auth)

        return person_platform_integration.user if person_platform_integration.user.present?

        unless person_platform_integration.persisted?
          user = current_user.present? ? current_user : find_by(email: auth['info']['email'])

          if user.blank?
            user = new
            user.skip_confirmation!
            user.password = ::Devise.friendly_token[0, 20]
            user.set_attributes_from_auth(auth)

            # Extract enhanced person data from OAuth and invitations
            person_attributes = build_person_attributes_from_oauth(person_platform_integration, auth)
            user.build_person(person_attributes)

            user.save
          end

          person_platform_integration.user = user
          person_platform_integration.person = user.person

          person_platform_integration.save
        end

        person_platform_integration.user
      end

      # Builds person attributes from OAuth data with fallbacks
      # @param integration [PersonPlatformIntegration] the OAuth integration
      # @param auth [OmniAuth::AuthHash] the OAuth authentication hash
      # @return [Hash] person attributes
      def self.build_person_attributes_from_oauth(integration, auth)
        email_username = auth.info.email&.split('@')&.first || 'user'

        {
          name: integration.name ||
            auth.info.name ||
            email_username.capitalize.tr('_', ' '),
          identifier: integration.handle ||
            auth.info.nickname ||
            email_username.parameterize,
          description: extract_bio_from_oauth(auth)
        }.compact # Remove nil values
      end

      # Extracts bio/description from OAuth provider
      # @param auth [OmniAuth::AuthHash] the OAuth authentication hash
      # @return [String, nil] the extracted bio
      def self.extract_bio_from_oauth(auth)
        # GitHub provides user bio in extra.raw_info.bio
        return auth.extra.raw_info.bio if auth.extra&.raw_info&.bio.present?

        # Twitter/X provides description in info.description
        return auth.info.description if auth.info&.description.present?

        # Generic fallback
        auth.info&.description || auth.extra&.raw_info&.description
      end

      def set_attributes_from_auth(auth)
        self.email = auth.info.email
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
