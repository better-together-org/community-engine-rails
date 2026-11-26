# frozen_string_literal: true

module BetterTogether
  # Decides who may administer a platform's feature access grants and quota grants.
  #
  # Grants are capacity and entitlement, so a platform may not hand them to itself unless it governs itself:
  # - a platform with an effective operator association is governed by that operator. A local operator's
  #   stewards act through the association's `billing` scope; a remote operator acts from its own app, so
  #   nobody on the managed platform can change its grants while that edge is in force (revoking the
  #   association returns the platform to self-governance);
  # - the host (operator) platform with no operator above it governs itself, so its stewards configure it fully;
  # - any other platform with no operator (a hosted platform) is governed by the host platform's stewards.
  module PlatformGrantAuthority
    GRANT_SCOPE = 'billing'
    MANAGE_PERMISSIONS = %w[manage_platform manage_platform_settings].freeze

    private

    def grant_authority_for?(target)
      return false unless agent.present? && target.present?
      return false if target.remote?

      edges = governing_edges(target)
      return operator_steward_through?(edges) if edges.any?
      return manages_platform?(target) if self_governing?(target)

      manages_platform?(grant_host_platform)
    end

    def governing_edges(target)
      PlatformAssociation.authority.for_managed(target).in_force.select(&:effective?)
    end

    def operator_steward_through?(edges)
      edges.any? do |edge|
        operator = edge.operator_platform
        operator.present? && !operator.remote? &&
          edge.effective_scopes.include?(GRANT_SCOPE) && manages_platform?(operator)
      end
    end

    def self_governing?(target)
      target.host? || target.is_a?(BetterTogether::OperatorPlatform)
    end

    def grant_host_platform
      Current.host_platform || BetterTogether::Platform.find_by(host: true)
    end

    def manages_platform?(platform)
      platform.present? && MANAGE_PERMISSIONS.any? { |permission| agent.permitted_to?(permission, platform) }
    end
  end
end
