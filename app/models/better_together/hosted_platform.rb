# frozen_string_literal: true

module BetterTogether
  # A tenant platform hosted by an operator, in the same instance or managed remotely.
  class HostedPlatform < Platform
    include PlatformSubtype
  end
end
