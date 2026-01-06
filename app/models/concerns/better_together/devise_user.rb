# frozen_string_literal: true

module BetterTogether
  # Represents a devise-powered user model
  module DeviseUser # rubocop:todo Metrics/ModuleLength
    extend ActiveSupport::Concern

    included do # rubocop:todo Metrics/BlockLength
      include FriendlySlug

      slugged :email

      has_many :person_platform_integrations, dependent: :destroy

      validates :email, presence: true, uniqueness: { case_sensitive: false }

      def self.from_omniauth(person_platform_integration:, auth:, current_user:, invitations: {})
        person_platform_integration = PersonPlatformIntegration.update_or_initialize(person_platform_integration, auth)

        # Check if integration already belongs to a different user
        if person_platform_integration.user.present? && current_user.present? &&
           person_platform_integration.user.id != current_user.id
          raise ArgumentError,
                'This OAuth account is already connected to another user. Please use a different account or sign in with the existing account.'
        end

        # Check if current user already has THIS integration connected (trying to re-connect same account)
        if current_user.present? && person_platform_integration.user.present? &&
           person_platform_integration.user.id == current_user.id
          provider_name = auth.provider.to_s.titleize
          raise ArgumentError,
                I18n.t('better_together.person_platform_integrations.create.already_connected',
                       provider: provider_name)
        end

        # Check if current user already has a DIFFERENT integration for this provider
        if current_user.present? && person_platform_integration.new_record?
          existing_integration = current_user.person_platform_integrations.find_by(provider: auth.provider)
          if existing_integration.present?
            provider_name = auth.provider.to_s.titleize
            raise ArgumentError,
                  I18n.t('better_together.person_platform_integrations.create.already_connected',
                         provider: provider_name)
          end
        end

        # If integration already has a user, return that user (for OAuth sign-in)
        return person_platform_integration.user if person_platform_integration.user.present?

        user = find_or_initialize_user(auth, current_user)

        if user.blank?
          # No existing user - create new OAuth user
          user = setup_new_oauth_user(new, auth)
          assign_person_to_user(user, person_platform_integration, auth, invitations)
          return nil unless user.save
        end

        # Link integration to existing or current user
        # This handles both: matched by email OR currently signed-in user
        link_integration_to_user(person_platform_integration, user)
      end

      # Finds existing user or returns nil for new OAuth sign-in
      # @param auth [OmniAuth::AuthHash] the OAuth authentication hash
      # @param current_user [User, nil] the currently signed-in user
      # @return [User, nil] existing user or nil
      # @raise [ArgumentError] if OAuth email belongs to different user than current_user
      def self.find_or_initialize_user(auth, current_user)
        oauth_email = auth.dig('info', 'email')

        # If user is signed in, verify OAuth email matches their account
        if current_user.present?
          existing_user_with_email = find_by(email: oauth_email)

          # OAuth email belongs to a different user - security violation
          if existing_user_with_email.present? && existing_user_with_email.id != current_user.id
            provider_name = auth.provider.to_s.titleize
            raise ArgumentError,
                  I18n.t('better_together.person_platform_integrations.create.email_mismatch',
                         provider: provider_name,
                         email: oauth_email,
                         default: "Cannot connect #{provider_name} account: the email #{oauth_email} belongs to a different user. Please sign out and sign in with the correct account.")
          end

          return current_user
        end

        # No current user - find by email for existing user OAuth sign-in
        find_by(email: oauth_email)
      end
      private_class_method :find_or_initialize_user

      # Sets up a new user from OAuth data
      # @param user [User] the new user instance
      # @param auth [OmniAuth::AuthHash] the OAuth authentication hash
      # @return [User] the configured user
      def self.setup_new_oauth_user(user, auth)
        # Create as OauthUser subclass so we can identify OAuth-only accounts
        user = ::BetterTogether::OauthUser.new if user.new_record?
        user.skip_confirmation!
        user.password = ::Devise.friendly_token[0, 20]
        user.attributes_from_auth(auth)
        user
      end
      private_class_method :setup_new_oauth_user

      # Assigns person to user, either from invitation or new from OAuth
      # @param user [User] the user to assign person to
      # @param integration [PersonPlatformIntegration] the OAuth integration
      # @param auth [OmniAuth::AuthHash] the OAuth authentication hash
      # @param invitations [Hash] hash of invitation types to invitation objects
      def self.assign_person_to_user(user, integration, auth, invitations)
        existing_person = find_person_from_invitations(invitations)

        if existing_person
          user.person = existing_person
          update_person_from_oauth(existing_person, integration, auth)
        else
          person_attributes = build_person_attributes_from_oauth(integration, auth)
          user.build_person(person_attributes)
        end
      end
      private_class_method :assign_person_to_user

      # Links integration to user and person, saves integration
      # @param integration [PersonPlatformIntegration] the OAuth integration
      # @param user [User] the user to link to
      # @return [User, nil] the user if successful, nil otherwise
      def self.link_integration_to_user(integration, user)
        integration.user = user
        integration.person = user.person

        # Confirm user if they matched via email but weren't confirmed yet
        user.confirm if user.respond_to?(:confirm) && !user.confirmed?

        return nil unless integration.save

        # Notify user of new integration for security awareness
        BetterTogether::PersonPlatformIntegrationCreatedNotifier.with(
          record: integration,
          person_platform_integration: integration,
          recipient: user.person
        ).deliver_later(user.person)

        user
      end
      private_class_method :link_integration_to_user

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

        add_description_update(updates, person, auth)
        add_name_update(updates, person, integration, auth)

        person.update(updates) if updates.any?
      end

      # Adds description to updates hash if person lacks one and OAuth provides it
      # @param updates [Hash] hash to store pending updates
      # @param person [Person] the existing person record
      # @param auth [OmniAuth::AuthHash] the OAuth authentication hash
      def self.add_description_update(updates, person, auth)
        oauth_bio = extract_bio_from_oauth(auth)
        updates[:description] = oauth_bio if person.description.blank? && oauth_bio.present?
      end
      private_class_method :add_description_update

      # Adds name to updates hash if person lacks one and OAuth provides it
      # @param updates [Hash] hash to store pending updates
      # @param person [Person] the existing person record
      # @param integration [PersonPlatformIntegration] the OAuth integration
      # @param auth [OmniAuth::AuthHash] the OAuth authentication hash
      def self.add_name_update(updates, person, integration, auth)
        oauth_name = extract_person_name(integration, auth)
        updates[:name] = oauth_name if person.name.blank? && oauth_name.present?
      end
      private_class_method :add_name_update

      # Builds person attributes from OAuth data with fallbacks
      # @param integration [PersonPlatformIntegration] the OAuth integration
      # @param auth [OmniAuth::AuthHash] the OAuth authentication hash
      # @return [Hash] person attributes
      def self.build_person_attributes_from_oauth(integration, auth)
        {
          name: extract_person_name(integration, auth),
          identifier: extract_person_identifier(integration, auth),
          description: extract_bio_from_oauth(auth)
        }.compact # Remove nil values
      end

      # Extracts person name from OAuth data with fallbacks
      # @param integration [PersonPlatformIntegration] the OAuth integration
      # @param auth [OmniAuth::AuthHash] the OAuth authentication hash
      # @return [String] the person name
      def self.extract_person_name(integration, auth)
        info_name = auth.dig('info', 'name') || auth.dig(:info, :name)
        email_username = extract_email_username(auth)

        integration.name ||
          info_name ||
          email_username.capitalize.tr('_', ' ')
      end
      private_class_method :extract_person_name

      # Extracts person identifier from OAuth data with fallbacks
      # @param integration [PersonPlatformIntegration] the OAuth integration
      # @param auth [OmniAuth::AuthHash] the OAuth authentication hash
      # @return [String] the person identifier
      def self.extract_person_identifier(integration, auth)
        info_nickname = auth.dig('info', 'nickname') || auth.dig(:info, :nickname)
        email_username = extract_email_username(auth)

        integration.handle ||
          info_nickname ||
          email_username.parameterize
      end
      private_class_method :extract_person_identifier

      # Extracts username from email address
      # @param auth [OmniAuth::AuthHash] the OAuth authentication hash
      # @return [String] the username portion of the email
      def self.extract_email_username(auth)
        email = auth.dig('info', 'email') || auth.dig(:info, :email)
        email&.split('@')&.first || 'user'
      end
      private_class_method :extract_email_username

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
        email_from_auth = auth.dig('info', 'email') || auth.dig(:info, :email)
        if email_from_auth.blank?
          raise ArgumentError,
                'Email not provided by OAuth provider. Please make your email public in your GitHub settings.'
        end

        self.email = email_from_auth
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

      # Check if user signed up via OAuth and has never set a password
      # Uses single-table inheritance to identify OAuth-only users
      # @return [Boolean] true if user is OauthUser type (signed up via OAuth, no password set)
      def oauth_without_password?
        is_a?(::BetterTogether::OauthUser)
      end

      # Override Devise to allow OAuth users to set their first password without current password
      # @param attributes [Hash] the attributes being updated
      # @return [Boolean] whether password is required
      def password_required?(attributes = nil)
        return false if oauth_without_password? && attributes&.key?(:password)

        super()
      end

      # Override Devise update_with_password to allow OAuth signup users to set password without current_password
      # OauthUser class handles conversion to regular User when password is set
      # @param params [Hash] the update parameters
      # @return [Boolean] whether the update was successful
      def update_with_password(params)
        if oauth_without_password? && params[:password].present?
          # OauthUser will handle this and convert to regular User
          params.delete(:current_password)
          update(params)
        else
          super
        end
      end
    end
  end
end
