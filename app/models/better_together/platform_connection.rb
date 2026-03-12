# frozen_string_literal: true

module BetterTogether
  # Durable directed edge between two platforms in the federated registry.
  class PlatformConnection < ApplicationRecord
    require 'storext'

    include ::Storext.model

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

    store_attributes :settings do
      content_sharing_policy String, default: 'none'
      federation_auth_policy String, default: 'none'
      share_posts Boolean, default: false
      share_pages Boolean, default: false
      share_events Boolean, default: false
      allow_identity_scope Boolean, default: false
      allow_profile_read_scope Boolean, default: false
      allow_content_read_scope Boolean, default: false
      allow_content_write_scope Boolean, default: false
      sync_cursor String, default: ''
      last_sync_status String, default: 'idle'
      last_sync_started_at String, default: ''
      last_synced_at String, default: ''
      last_sync_error_at String, default: ''
      last_sync_error_message String, default: ''
      last_sync_item_count Integer, default: 0
      federation_access_token String, default: ''
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
    before_validation :ensure_federation_access_token

    scope :active, -> { where(status: STATUS_VALUES[:active]) }
    scope :for_platform, lambda { |platform|
      where(source_platform: platform).or(where(target_platform: platform))
    }

    def involves?(platform)
      source_platform_id == platform.id || target_platform_id == platform.id
    end

    def peer_for(platform)
      return target_platform if source_platform_id == platform.id
      return source_platform if target_platform_id == platform.id

      nil
    end

    def shared_content_types
      [].tap do |types|
        types << 'posts' if share_posts?
        types << 'pages' if share_pages?
        types << 'events' if share_events?
      end
    end

    def federation_scope_types
      [].tap do |types|
        types << 'identity' if allow_identity_scope?
        types << 'profile_read' if allow_profile_read_scope?
        types << 'content_read' if allow_content_read_scope?
        types << 'content_write' if allow_content_write_scope?
      end
    end

    def allows_content_type?(content_type)
      shared_content_types.include?(normalize_policy_key(content_type))
    end

    def allows_federation_scope?(scope_type)
      federation_scope_types.include?(normalize_policy_key(scope_type))
    end

    def mirrored_content_enabled?
      content_sharing_policy.in?(%w[mirror_network_feed mirrored_publish_back])
    end

    def publish_back_enabled?
      content_sharing_policy == 'mirrored_publish_back' && allows_federation_scope?('content_write')
    end

    def login_enabled?
      federation_auth_policy.in?(%w[login_only api_read api_write]) && allows_federation_scope?('identity')
    end

    def api_read_enabled?
      federation_auth_policy.in?(%w[api_read api_write]) && allows_federation_scope?('content_read')
    end

    def api_write_enabled?
      federation_auth_policy == 'api_write' && allows_federation_scope?('content_write')
    end

    def sync_idle?
      last_sync_status == 'idle'
    end

    def sync_running?
      last_sync_status == 'running'
    end

    def sync_succeeded?
      last_sync_status == 'succeeded'
    end

    def sync_failed?
      last_sync_status == 'failed'
    end

    def sync_healthy?
      !sync_failed?
    end

    def last_sync_started_at_time
      parse_time_value(last_sync_started_at)
    end

    def last_synced_at_time
      parse_time_value(last_synced_at)
    end

    def last_sync_error_at_time
      parse_time_value(last_sync_error_at)
    end

    def mark_sync_started!(cursor: nil, started_at: Time.current)
      update!(
        sync_cursor: normalized_cursor(cursor),
        last_sync_status: 'running',
        last_sync_started_at: started_at.iso8601,
        last_sync_error_at: '',
        last_sync_error_message: ''
      )
    end

    def mark_sync_succeeded!(cursor: nil, item_count: 0, synced_at: Time.current)
      update!(
        sync_cursor: normalized_cursor(cursor),
        last_sync_status: 'succeeded',
        last_synced_at: synced_at.iso8601,
        last_sync_error_at: '',
        last_sync_error_message: '',
        last_sync_item_count: item_count.to_i
      )
    end

    def mark_sync_failed!(message:, cursor: nil, failed_at: Time.current)
      update!(
        sync_cursor: normalized_cursor(cursor),
        last_sync_status: 'failed',
        last_sync_error_at: failed_at.iso8601,
        last_sync_error_message: message.to_s.truncate(500)
      )
    end

    def rotate_federation_access_token!
      update!(federation_access_token: generate_federation_access_token)
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

    def normalize_content_policy_settings!
      if content_sharing_policy == 'none'
        self.share_posts = false
        self.share_pages = false
        self.share_events = false
      end

      self.content_sharing_enabled = content_sharing_policy != 'none'
    end

    def normalize_federation_policy_settings!
      if federation_auth_policy == 'none'
        self.allow_identity_scope = false
        self.allow_profile_read_scope = false
        self.allow_content_read_scope = false
        self.allow_content_write_scope = false
      end

      self.federation_auth_enabled = federation_auth_policy != 'none'
    end

    def normalize_policy_key(value)
      value.to_s.strip.downcase
    end

    def ensure_federation_access_token
      self.federation_access_token = generate_federation_access_token if federation_access_token.blank?
    end

    def generate_federation_access_token
      SecureRandom.hex(32)
    end

    def normalized_cursor(value)
      value.to_s
    end

    def parse_time_value(value)
      return if value.blank?

      Time.zone.parse(value)
    rescue ArgumentError
      nil
    end
  end
end
