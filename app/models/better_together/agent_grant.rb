# frozen_string_literal: true

module BetterTogether
  # Delegation from a human operator to a Robot on one platform, optionally
  # limited to one community. It is the only way a robot gains authority; a
  # request is further bounded by the operator's current permissions.
  class AgentGrant < ApplicationRecord
    self.table_name = 'better_together_agent_grants'

    belongs_to :robot, class_name: 'BetterTogether::Robot'
    belongs_to :platform, class_name: 'BetterTogether::Platform'
    belongs_to :operator, class_name: 'BetterTogether::Person'
    belongs_to :community, class_name: 'BetterTogether::Community', optional: true
    belongs_to :granted_by, class_name: 'BetterTogether::Person', optional: true

    validates :robot, :platform, :operator, presence: true
    validate :scopes_known
    validate :scopes_within_operator_authority

    scope :active, lambda {
      where(revoked_at: nil).where(arel_table[:expires_at].eq(nil).or(arel_table[:expires_at].gt(Time.current)))
    }

    def active?
      revoked_at.nil? && (expires_at.nil? || expires_at.future?)
    end

    private

    def scopes_known
      unknown = scopes.to_a - OauthApplication.available_scopes.map(&:to_s)
      errors.add(:scopes, "unknown: #{unknown.join(', ')}") if unknown.any?
    end

    def scopes_within_operator_authority
      return if operator.blank? || operator.permitted_to?('manage_platform')

      trusted_scopes_allowed
      community_authority_allowed
    end

    # Trusted-only scopes (admin, mcp_access) need a platform manager.
    def trusted_scopes_allowed
      trusted = scopes.to_a & OauthApplication::TRUSTED_ONLY_SCOPES
      errors.add(:scopes, "cannot include #{trusted.join(', ')} for this operator") if trusted.any?
    end

    # A community-limited grant needs authority over that community.
    def community_authority_allowed
      return if community.blank? || operator.permitted_to?('update_community', community)

      errors.add(:community, 'is outside the operator authority')
    end
  end
end
