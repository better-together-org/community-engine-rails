# frozen_string_literal: true

module BetterTogether
  # Registry lifecycle and federation defaults for Platform.
  module PlatformRegistryDefaults
    extend ActiveSupport::Concern

    private

    def apply_platform_registry_defaults
      self.network_visibility = 'private' if network_visibility.blank?
      apply_connection_bootstrap_state_default
      apply_local_hosted_defaults if local_hosted?
      apply_community_engine_defaults if community_engine?
    end

    def apply_connection_bootstrap_state_default
      self.connection_bootstrap_state ||=
        local_hosted? ? 'pending_host_request' : 'pending_review'
    end

    def apply_local_hosted_defaults
      self.software_variant ||= 'community_engine'
    end

    def apply_community_engine_defaults
      self.federation_protocol ||= 'ce_oauth'
      self.oauth_issuer_url ||= resolved_host_url
    end

    def sync_primary_platform_domain!
      return unless self.class.connection.data_source_exists?('better_together_platform_domains')
      return if external?

      hostname = platform_hostname_from_host_url
      return if hostname.blank?

      primary_domain = platform_domains.primary.first_or_initialize
      primary_domain.hostname = hostname
      primary_domain.active = true
      primary_domain.primary = true
      primary_domain.save! if primary_domain.new_record? || primary_domain.changed?
    end

    def platform_hostname_from_host_url
      return if host_url.blank?

      BetterTogether::PlatformDomain.normalize_hostname(URI.parse(host_url).host)
    rescue URI::InvalidURIError
      nil
    end
  end
end
