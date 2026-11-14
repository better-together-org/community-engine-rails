# frozen_string_literal: true

module BetterTogether
  # Explicit per-person override for access to gated engine features.
  class FeatureAccessGrant < PlatformRecord
    ACCESS_LEVELS = {
      beta: 'beta',
      alpha: 'alpha'
    }.freeze

    belongs_to :person, class_name: '::BetterTogether::Person'
    belongs_to :granted_by_person, class_name: '::BetterTogether::Person', optional: true

    enum :access_level, ACCESS_LEVELS, validate: true

    before_validation :revoke_self_if_expired
    before_validation :revoke_expired_conflicts

    validates :feature_key, presence: true
    validate :ensure_no_other_active_grant
    validate :ensure_known_feature_key

    scope :active, lambda {
      where(revoked_at: nil)
        .where(arel_table[:expires_at].eq(nil).or(arel_table[:expires_at].gt(Time.current)))
    }

    def revoke!(revoked_time: Time.current)
      return self if revoked_at.present?

      update!(revoked_at: revoked_time)
    end

    def active_now?
      revoked_at.blank? && (expires_at.blank? || expires_at.future?)
    end

    private

    def ensure_no_other_active_grant
      return unless grant_lookup_ready?

      conflicting_grants = matching_active_grants
      conflicting_grants = conflicting_grants.where.not(id:) if persisted?
      return unless conflicting_grants.exists?

      errors.add(:person_id, :taken)
    end

    def ensure_known_feature_key
      return if feature_key.blank?
      return if BetterTogether::FeatureRegistry.find(feature_key).present?
      return if persisted? && feature_key_in_database == feature_key

      errors.add(:feature_key, :inclusion)
    end

    def revoke_self_if_expired
      return if revoked_at.present? || expires_at.blank? || expires_at.future?

      self.revoked_at = expires_at
    end

    def revoke_expired_conflicts
      return unless grant_lookup_ready?

      matching_unrevoked_grants.where.not(expires_at: nil)
                               .where(expired_grants_predicate)
                               .update_all(revoked_at: Time.current, updated_at: Time.current)
    end

    def grant_lookup_ready?
      platform_id.present? && person_id.present? && feature_key.present?
    end

    def matching_active_grants
      self.class.active.where(grant_lookup_attributes)
    end

    def matching_unrevoked_grants
      self.class.where(grant_lookup_attributes.merge(revoked_at: nil))
    end

    def grant_lookup_attributes
      {
        platform_id:,
        person_id:,
        feature_key:
      }
    end

    def expired_grants_predicate
      self.class.arel_table[:expires_at].lteq(Time.current)
    end
  end
end
