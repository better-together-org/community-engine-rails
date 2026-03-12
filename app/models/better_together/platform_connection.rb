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

    belongs_to :source_platform, class_name: '::BetterTogether::Platform'
    belongs_to :target_platform, class_name: '::BetterTogether::Platform'

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
    end

    enum :status, STATUS_VALUES, default: :pending, validate: true
    enum :connection_kind, CONNECTION_KINDS, default: :peer, validate: true

    validates :source_platform_id, uniqueness: { scope: :target_platform_id }
    validates :content_sharing_enabled, :federation_auth_enabled, inclusion: { in: [true, false] }
    validates :content_sharing_policy, inclusion: { in: CONTENT_SHARING_POLICIES.values }
    validates :federation_auth_policy, inclusion: { in: FEDERATION_AUTH_POLICIES.values }
    validate :source_and_target_must_differ

    before_validation :apply_connection_policy_defaults

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
  end
end
