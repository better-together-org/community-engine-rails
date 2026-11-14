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

    # Check if this application is trusted (owned by a platform manager).
    # Trusted applications skip the OAuth authorization screen.
    # @return [Boolean]
    def trusted?
      !!owner&.permitted_to?('manage_platform')
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
      return if trusted?

      invalid_scopes = untrusted_scopes
      return if invalid_scopes.empty?

      errors.add(:scopes, "cannot include: #{invalid_scopes.join(', ')}")
    end
  end
end
