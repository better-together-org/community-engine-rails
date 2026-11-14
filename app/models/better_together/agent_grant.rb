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
    validate :robot_available_on_platform
    validate :community_on_platform
    validate :one_open_grant_per_scope, if: -> { revoked_at.nil? }
    validate :scopes_within_authority, if: :authority_check_needed?

    scope :active, lambda {
      where(revoked_at: nil).where(arel_table[:expires_at].eq(nil).or(arel_table[:expires_at].gt(Time.current)))
    }

    def active?
      revoked_at.nil? && (expires_at.nil? || expires_at.future?)
    end

    # Skips the operator-authority check so a grant can always be revoked,
    # including after its operator has been demoted.
    def revoke!(at: Time.current)
      update_columns(revoked_at: at, updated_at: at) # rubocop:disable Rails/SkipsModelValidations
    end

    private

    def authority_check_needed?
      new_record? || will_save_change_to_scopes? || will_save_change_to_community_id?
    end

    def scopes_known
      unknown = scopes.to_a - OauthApplication.available_scopes.map(&:to_s)
      errors.add(:scopes, "unknown: #{unknown.join(', ')}") if unknown.any?
    end

    # Operator and grantor must each hold the authority being delegated.
    def scopes_within_authority
      { operator: operator, granted_by: granted_by }.each do |field, person|
        next if person.blank? || person.permitted_to?('manage_platform')

        trusted_scopes_allowed(field)
        community_authority_allowed(field, person)
      end
    end

    # Trusted-only scopes (admin, mcp_access) need a platform manager.
    def trusted_scopes_allowed(field)
      trusted = scopes.to_a & OauthApplication::TRUSTED_ONLY_SCOPES
      errors.add(:scopes, "cannot include #{trusted.join(', ')} for this #{field}") if trusted.any?
    end

    # A community-limited grant needs authority over that community.
    def community_authority_allowed(field, person)
      return if community.blank? || person.permitted_to?('update_community', community)

      errors.add(:community, "is outside the #{field} authority")
    end

    def robot_available_on_platform
      return if robot.blank? || platform.blank?
      return if robot.global_fallback? || robot.managed_by_platform?(platform)

      errors.add(:robot, 'belongs to a different platform')
    end

    # A community without a platform belongs to the host platform.
    def community_on_platform
      return if community.blank? || platform.blank?
      return if community.platform_id == platform_id || (community.platform_id.nil? && platform.host?)

      errors.add(:community, 'does not belong to the grant platform')
    end

    def one_open_grant_per_scope
      return if robot_id.blank? || platform_id.blank?

      duplicates = self.class.where(robot_id:, platform_id:, community_id:, revoked_at: nil).where.not(id:)
      errors.add(:base, 'an open grant already exists for this robot and scope') if duplicates.exists?
    end
  end
end
