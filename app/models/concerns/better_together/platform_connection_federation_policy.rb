# frozen_string_literal: true

module BetterTogether
  # Mixin for federation content and auth policy evaluation on PlatformConnection.
  module PlatformConnectionFederationPolicy
    extend ActiveSupport::Concern

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
        types << 'linked_content_read' if allow_linked_content_read_scope?
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

    def linked_content_read_enabled?
      federation_auth_policy.in?(%w[api_read api_write]) &&
        allows_federation_scope?('content_read') &&
        allows_federation_scope?('linked_content_read')
    end

    def api_write_enabled?
      federation_auth_policy == 'api_write' && allows_federation_scope?('content_write')
    end

    def metadata_sync_depth?
      sync_depth == 'metadata'
    end

    def standard_sync_depth?
      sync_depth.in?(%w[standard full])
    end

    def full_sync_depth?
      sync_depth == 'full'
    end

    private

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
        self.allow_linked_content_read_scope = false
        self.allow_content_write_scope = false
      end

      self.federation_auth_enabled = federation_auth_policy != 'none'
    end

    def normalize_policy_key(value)
      value.to_s.strip.downcase
    end
  end
end
