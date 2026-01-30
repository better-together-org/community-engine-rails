# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # Backwards-compatible controller alias for person community memberships
      class CommunityMembershipsController < PersonCommunityMembershipsController
      end
    end
  end
end
