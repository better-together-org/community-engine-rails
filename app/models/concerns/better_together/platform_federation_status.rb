# frozen_string_literal: true

module BetterTogether
  # Federation status query methods for Platform.
  module PlatformFederationStatus
    extend ActiveSupport::Concern

    def local_hosted?
      !external?
    end

    def external_peer?
      external?
    end

    def community_engine?
      local_hosted? || software_variant == 'community_engine'
    end

    def federated?
      federation_protocol.present?
    end

    def effective_oauth_issuer_url
      oauth_issuer_url.presence || (community_engine? ? resolved_host_url : nil)
    end

    def pending_host_connection_bootstrap?
      local_hosted? && connection_bootstrap_state == 'pending_host_request'
    end

    def platform_connections
      BetterTogether::PlatformConnection.for_platform(self)
    end

    def connected_platforms
      outgoing_platform_connections.active.includes(:target_platform).map(&:target_platform) +
        incoming_platform_connections.active.includes(:source_platform).map(&:source_platform)
    end
  end
end
