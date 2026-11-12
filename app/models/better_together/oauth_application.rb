# frozen_string_literal: true

module BetterTogether
  # OAuth2 application registration for API and MCP access.
  # Each n8n workflow, management tool instance, or bot gets its own
  # application with scoped permissions.
  #
  # Supports both client_credentials (machine-to-machine) and
  # authorization_code (user-delegated) grant flows.
  class OauthApplication < PlatformRecord
    include ::Doorkeeper::Orm::ActiveRecord::Mixins::Application

    self.table_name = 'better_together_oauth_applications'

    belongs_to :owner,
               class_name: 'BetterTogether::Person',
               optional: true,
               inverse_of: :oauth_applications
    belongs_to :platform,
               class_name: 'BetterTogether::Platform',
               optional: true
    belongs_to :robot, class_name: 'BetterTogether::Robot', optional: true
    belongs_to :community, class_name: 'BetterTogether::Community', optional: true

    scope :for_platform, ->(platform) { where(platform: platform) }

    validates :name, presence: true
    validate :validate_scopes_for_owner
    validate :agent_credential_bound_to_platform

    TRUSTED_ONLY_SCOPES = %w[admin mcp_access].freeze

    # Trusted (skips the consent screen) only when the application belongs to the host
    # platform and is owned by a manager of it. Tenant owned apps always get consent.
    # @return [Boolean]
    def trusted?
      !!(platform&.host? && owner&.platform_manager?(platform))
    end

    # A token is only valid on the platform its application was registered for.
    # Legacy applications without a platform are treated as host platform only.
    def usable_on?(request_platform)
      return false if request_platform.blank?

      (platform || BetterTogether::Platform.find_by(host: true))&.id == request_platform.id
    end

    # An agent credential authenticates as a Robot instead of its owner.
    # @return [Boolean]
    def agent?
      robot_id.present?
    end

    # List of all available OAuth scopes for documentation
    # @return [Array<String>]
    def self.available_scopes
      Doorkeeper.config.scopes.to_a
    end

    def untrusted_scopes
      scopes.to_a & TRUSTED_ONLY_SCOPES
    end

    # Permitted attributes for strong parameters
    # @return [Array<Symbol>]
    def self.permitted_attributes(id: false, destroy: false)
      attrs = %i[name redirect_uri scopes confidential]
      attrs << :id if id
      attrs << :_destroy if destroy
      attrs
    end

    private

    def agent_credential_bound_to_platform
      return unless agent? && platform_id.blank?

      errors.add(:platform, 'is required for agent credentials')
    end

    def validate_scopes_for_owner
      return if trusted? || owner&.platform_manager?(platform || Current.platform)

      invalid_scopes = untrusted_scopes
      return if invalid_scopes.empty?

      errors.add(:scopes, "cannot include: #{invalid_scopes.join(', ')}")
    end
  end
end
