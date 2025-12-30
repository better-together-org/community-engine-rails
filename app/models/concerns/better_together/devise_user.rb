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

      # rubocop:todo Metrics/MethodLength
      # rubocop:todo Lint/CopDirectiveSyntax
      def self.from_omniauth(person_platform_integration:, auth:, current_user:, invitations: {}) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        # rubocop:enable Lint/CopDirectiveSyntax
        # PersonPlatformIntegration will automatically find the correct external OAuth platform
        person_platform_integration = PersonPlatformIntegration.update_or_initialize(person_platform_integration, auth)

        return person_platform_integration.user if person_platform_integration.user.present?

        unless person_platform_integration.persisted?
          user = current_user.present? ? current_user : find_by(email: auth.dig('info', 'email'))

          if user.blank?
            user = new
            user.skip_confirmation!
            user.password = ::Devise.friendly_token[0, 20]
            user.attributes_from_auth(auth)

            # Check if we have an existing person from invitation
            existing_person = find_person_from_invitations(invitations)

            if existing_person
              # Use existing person from invitation
              user.person = existing_person
              # Update person with OAuth data if better quality
              update_person_from_oauth(existing_person, person_platform_integration, auth)
            else
              # Extract enhanced person data from OAuth
              person_attributes = build_person_attributes_from_oauth(person_platform_integration, auth)
              user.build_person(person_attributes)
            end

            return nil unless user.save
          end

          person_platform_integration.user = user
          person_platform_integration.person = user.person

          return nil unless person_platform_integration.save
        end

        person_platform_integration.user
      end
      # rubocop:enable Metrics/MethodLength

      # Find existing person from any invitation
      # @param invitations [Hash] hash of invitation types to invitation objects
      # @return [Person, nil]
      def self.find_person_from_invitations(invitations)
        return nil if invitations.blank?

        %i[platform community event].each do |type|
          invitation = invitations[type]
          return invitation.invitee if invitation&.invitee.present?
        end

        nil
      end

      # Update existing person with OAuth data if it improves quality
      # @param person [Person] the existing person record
      # @param integration [PersonPlatformIntegration] the OAuth integration
      # @param auth [OmniAuth::AuthHash] the OAuth authentication hash
      def self.update_person_from_oauth(person, integration, auth)
        updates = {}

        # Add description if person doesn't have one but OAuth provides it
        oauth_bio = extract_bio_from_oauth(auth)
        updates[:description] = oauth_bio if person.description.blank? && oauth_bio.present?

        # Update name if invitation had generic name but OAuth has better data
        info_name = auth.dig('info', 'name') || auth.dig(:info, :name)
        oauth_name = integration.name || info_name
        if person.name.blank? && oauth_name.present?
          updates[:name] = oauth_name
        end

        person.update(updates) if updates.any?
      end

      # Builds person attributes from OAuth data with fallbacks
      # @param integration [PersonPlatformIntegration] the OAuth integration
      # @param auth [OmniAuth::AuthHash] the OAuth authentication hash
      # @return [Hash] person attributes
      def self.build_person_attributes_from_oauth(integration, auth) # rubocop:todo Metrics/CyclomaticComplexity
        email = auth.dig('info', 'email') || auth.dig(:info, :email)
        email_username = email&.split('@')&.first || 'user'

        info_name = auth.dig('info', 'name') || auth.dig(:info, :name)
        info_nickname = auth.dig('info', 'nickname') || auth.dig(:info, :nickname)

        {
          name: integration.name ||
            info_name ||
            email_username.capitalize.tr('_', ' '),
          identifier: integration.handle ||
            info_nickname ||
            email_username.parameterize,
          description: extract_bio_from_oauth(auth)
        }.compact # Remove nil values
      end

      # Extracts bio/description from OAuth provider
      # @param auth [OmniAuth::AuthHash] the OAuth authentication hash
      # @return [String, nil] the extracted bio
      def self.extract_bio_from_oauth(auth)
        extract_github_bio(auth) ||
          extract_twitter_bio(auth) ||
          extract_generic_bio(auth)
      end

      def self.extract_github_bio(auth)
        bio = auth.dig('extra', 'raw_info', 'bio') || auth.dig(:extra, :raw_info, :bio)
        bio if bio.present?
      end
      private_class_method :extract_github_bio

      def self.extract_twitter_bio(auth)
        desc = auth.dig('info', 'description') || auth.dig(:info, :description)
        desc if desc.present?
      end
      private_class_method :extract_twitter_bio

      def self.extract_generic_bio(auth)
        auth.dig('info', 'description') ||
          auth.dig(:info, :description) ||
          auth.dig('extra', 'raw_info', 'description') ||
          auth.dig(:extra, :raw_info, :description)
      end
      private_class_method :extract_generic_bio

      def attributes_from_auth(auth)
        self.email = auth.dig('info', 'email') || auth.dig(:info, :email)
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
