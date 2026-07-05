# frozen_string_literal: true

module BetterTogether
  # Shared Pundit policy helpers for privacy-scoped, self-service-publishable
  # models. Assumes inclusion into a BetterTogether::ApplicationPolicy
  # subclass (relies on #user, #agent, #record, #permitted_to?, and the
  # community-resolution helpers already defined there).
  module SelfServicePublishablePolicy
    extend ActiveSupport::Concern

    # Canonical platform-manager bypass, replacing the repeated
    # `permitted_to?('manage_platform_settings') || permitted_to?('manage_platform')`
    # duplicated across several policies.
    def platform_manager?
      permitted_to?('manage_platform_settings') || permitted_to?('manage_platform')
    end

    # Canonical creator/ownership check.
    def creator_of?(target = record)
      target.respond_to?(:creator_id) && agent.present? && target.creator_id == agent.id
    end

    # Generic agreement-acceptance check, delegating to the already-generic
    # GovernedAgent#accepted_agreement?.
    def accepted_agreement?(identifier)
      agent.present? && agent.accepted_agreement?(identifier)
    end

    def accepted_content_publishing_agreement?
      accepted_agreement?(BetterTogether::PublicVisibilityGate::AGREEMENT_IDENTIFIER)
    end

    # Composite self-serve creation gate: active membership in the resolved
    # target community, plus acceptance of the content publishing agreement.
    # Individual policies may pass an explicit `community:` when the default
    # resolver (`resolved_community_for`) wouldn't resolve the right target
    # (e.g. Event, which has no direct :community association).
    def self_service_content_creator?(community: resolved_community_for(record))
      return false unless user.present? && agent.present?
      return false unless community.present?

      member_of_resolved_community?(community) && accepted_content_publishing_agreement?
    end
  end
end
