# frozen_string_literal: true

module BetterTogether
  module Safety
    # Moderator-recorded protective or accountability action for a safety case.
    class Action < ApplicationRecord
      self.table_name = 'better_together_safety_actions'

      enum :action_type, {
        content_hidden: 'content_hidden',
        content_removed: 'content_removed',
        contact_restriction: 'contact_restriction',
        messaging_restriction: 'messaging_restriction',
        event_restriction: 'event_restriction',
        temporary_suspension: 'temporary_suspension',
        restorative_referral: 'restorative_referral',
        watch_flag: 'watch_flag'
      }, prefix: true

      enum :status, {
        active: 'active',
        completed: 'completed',
        cancelled: 'cancelled'
      }, prefix: true

      belongs_to :safety_case, class_name: 'BetterTogether::Safety::Case', inverse_of: :actions
      belongs_to :actor, class_name: 'BetterTogether::Person', inverse_of: :acted_safety_actions
      belongs_to :approved_by, class_name: 'BetterTogether::Person', optional: true, inverse_of: :approved_safety_actions

      validates :action_type, presence: true
      validates :status, presence: true
      validates :reason, presence: true
      validates :review_at, presence: true, if: :status_active?

      scope :active, -> { where(status: 'active') }
    end
  end
end
