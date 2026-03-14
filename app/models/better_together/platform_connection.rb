# frozen_string_literal: true

module BetterTogether
  # Durable directed edge between two platforms in the federated registry.
  class PlatformConnection < ApplicationRecord # rubocop:disable Metrics/ClassLength
    require 'storext'

    include ::Storext.model
    include PlatformConnectionSyncTracking
    include PlatformConnectionFederationPolicy
    include PlatformConnectionOauthCredentials

    STATUS_VALUES = {
      pending: 'pending',
      active: 'active',
      suspended: 'suspended',
      blocked: 'blocked'
    }.freeze

    CONNECTION_KINDS = {
      peer: 'peer',
      member: 'member'
    }.freeze

    CONTENT_SHARING_POLICIES = {
      none: 'none',
      selective: 'selective',
      mirror_network_feed: 'mirror_network_feed',
      mirrored_publish_back: 'mirrored_publish_back'
    }.freeze

    FEDERATION_AUTH_POLICIES = {
      none: 'none',
      login_only: 'login_only',
      api_read: 'api_read',
      api_write: 'api_write'
    }.freeze

    SYNC_STATUS_VALUES = {
      idle: 'idle',
      running: 'running',
      succeeded: 'succeeded',
      failed: 'failed'
    }.freeze

    belongs_to :source_platform, class_name: '::BetterTogether::Platform'
    belongs_to :target_platform, class_name: '::BetterTogether::Platform'
    has_many :person_links, class_name: '::BetterTogether::PersonLink', dependent: :destroy
    has_many :federation_access_tokens,
             class_name: '::BetterTogether::FederationAccessToken',
             dependent: :destroy

    store_attributes :settings do
      content_sharing_policy String, default: 'none'
      federation_auth_policy String, default: 'none'
      share_posts Boolean, default: false
      share_pages Boolean, default: false
      share_events Boolean, default: false
      allow_identity_scope Boolean, default: false
      allow_profile_read_scope Boolean, default: false
      allow_content_read_scope Boolean, default: false
      allow_linked_content_read_scope Boolean, default: false
      allow_content_write_scope Boolean, default: false
      sync_cursor String, default: ''
      last_sync_status String, default: 'idle'
      last_sync_started_at String, default: ''
      last_synced_at String, default: ''
      last_sync_error_at String, default: ''
      last_sync_error_message String, default: ''
      last_sync_item_count Integer, default: 0
    end

    enum :status, STATUS_VALUES, default: :pending, validate: true
    enum :connection_kind, CONNECTION_KINDS, default: :peer, validate: true

    validates :source_platform_id, uniqueness: { scope: :target_platform_id }
    validates :content_sharing_enabled, :federation_auth_enabled, inclusion: { in: [true, false] }
    validates :content_sharing_policy, inclusion: { in: CONTENT_SHARING_POLICIES.values }
    validates :federation_auth_policy, inclusion: { in: FEDERATION_AUTH_POLICIES.values }
    validates :last_sync_status, inclusion: { in: SYNC_STATUS_VALUES.values }
    validate :source_and_target_must_differ

    before_validation :apply_connection_policy_defaults
    before_validation :ensure_oauth_client_credentials

    scope :active, -> { where(status: STATUS_VALUES[:active]) }
    scope :for_platform, lambda { |platform|
      where(source_platform: platform).or(where(target_platform: platform))
    }
    scope :content_read_capable, lambda {
      where("better_together_platform_connections.settings->>'federation_auth_policy' IN (?)", %w[api_read api_write])
        .where("(better_together_platform_connections.settings->>'allow_content_read_scope')::boolean = true")
    }
    scope :linked_content_read_capable, lambda {
      content_read_capable
        .where("(better_together_platform_connections.settings->>'allow_linked_content_read_scope')::boolean = true")
    }
    scope :not_syncing, lambda {
      where("better_together_platform_connections.settings->>'last_sync_status' != ? OR better_together_platform_connections.settings->>'last_sync_status' IS NULL", 'running')
    }

    def involves?(platform)
      source_platform_id == platform.id || target_platform_id == platform.id
    end

    def peer_for(platform)
      return target_platform if source_platform_id == platform.id
      return source_platform if target_platform_id == platform.id

      nil
    end

    private

    def source_and_target_must_differ
      return if source_platform_id.blank? || target_platform_id.blank?
      return unless source_platform_id == target_platform_id

      errors.add(:target_platform_id, 'must differ from source platform')
    end

    def apply_connection_policy_defaults
      self.content_sharing_policy ||= 'none'
      self.federation_auth_policy ||= 'none'

      normalize_content_policy_settings!
      normalize_federation_policy_settings!
    end
  end
end
