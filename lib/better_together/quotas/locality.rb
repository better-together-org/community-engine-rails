# frozen_string_literal: true

module BetterTogether
  module Quotas
    # Only local owners get quotas: a local platform, and the people and communities
    # that live on one. Federated peers, OAuth providers (Platform#external) and the
    # people/communities mirrored from them never do. Locality is Platform#external
    # (PlatformFederationStatus#local_hosted?), never `host: true` equality, so any
    # local platform on an instance qualifies.
    module Locality
      module_function

      def local_owner?(owner)
        return false if owner.nil?
        return owner.local_hosted? if owner.is_a?(BetterTogether::Platform)

        platform = owner.respond_to?(:platform) ? owner.platform : nil
        platform.nil? || platform.local_hosted?
      end
    end
  end
end
