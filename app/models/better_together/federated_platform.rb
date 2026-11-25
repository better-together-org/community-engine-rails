# frozen_string_literal: true

module BetterTogether
  # A remote Community Engine peer that is federated with but is neither hosted nor an identity provider.
  class FederatedPlatform < Platform
    include PlatformSubtype
  end
end
