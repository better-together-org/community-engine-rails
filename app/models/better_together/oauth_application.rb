# frozen_string_literal: true

module BetterTogether
  # OAuth2 application registration for API and MCP access.
  # Each n8n workflow, management tool instance, or bot gets its own
  # application with scoped permissions.
  #
  # Supports both client_credentials (machine-to-machine) and
  # authorization_code (user-delegated) grant flows.
  class OauthApplication < ApplicationRecord
    include ::Doorkeeper::Orm::ActiveRecord::Mixins::Application

    self.table_name = 'better_together_oauth_applications'

    belongs_to :owner,
               class_name: 'BetterTogether::Person',
               optional: true

    validates :name, presence: true
    validate :validate_scopes_for_owner

    TRUSTED_ONLY_SCOPES = %w[admin mcp_access].freeze

    # Check if this application is trusted (owned by a platform manager).
    # Trusted applications skip the OAuth authorization screen.
    # @return [Boolean]
    def trusted?
      !!owner&.permitted_to?('manage_platform')
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

    def validate_scopes_for_owner
      return if trusted?

      invalid_scopes = untrusted_scopes
      return if invalid_scopes.empty?

      errors.add(:scopes, "cannot include: #{invalid_scopes.join(', ')}")
    end
  end
end
