# frozen_string_literal: true

module BetterTogether
  # The app's host platform, and authorized remote platforms that operate (support) it.
  class OperatorPlatform < Platform
    include PlatformSubtype
  end
end
