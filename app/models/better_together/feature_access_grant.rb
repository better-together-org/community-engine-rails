# frozen_string_literal: true

module BetterTogether
  # Explicit per-person override for access to gated engine features.
  class FeatureAccessGrant < ApplicationRecord
    ACCESS_LEVELS = {
      beta: 'beta',
      alpha: 'alpha'
    }.freeze

    belongs_to :platform, class_name: '::BetterTogether::Platform'
    belongs_to :person, class_name: '::BetterTogether::Person'
    belongs_to :granted_by_person, class_name: '::BetterTogether::Person', optional: true

    enum :access_level, ACCESS_LEVELS, validate: true

    validates :feature_key, presence: true, inclusion: { in: ->(_record) { BetterTogether::FeatureRegistry.keys } }
    validates :person_id, uniqueness: {
      scope: %i[platform_id feature_key],
      conditions: -> { where(revoked_at: nil) }
    }

    scope :active, lambda {
      where(revoked_at: nil)
        .where(arel_table[:expires_at].eq(nil).or(arel_table[:expires_at].gt(Time.current)))
    }

    def revoke!(revoked_time: Time.current)
      update!(revoked_at: revoked_time)
    end

    def active_now?
      revoked_at.blank? && (expires_at.blank? || expires_at.future?)
    end
  end
end
