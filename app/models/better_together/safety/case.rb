# frozen_string_literal: true

module BetterTogether
  module Safety
    # Operational case opened from a user safety report.
    class Case < ApplicationRecord
      self.table_name = 'better_together_safety_cases'

      enum :status, {
        submitted: 'submitted',
        triaged: 'triaged',
        needs_reporter_followup: 'needs_reporter_followup',
        restorative_in_progress: 'restorative_in_progress',
        protective_action_in_effect: 'protective_action_in_effect',
        resolved: 'resolved',
        closed_no_action: 'closed_no_action'
      }, prefix: true

      enum :lane, {
        restorative: 'restorative',
        immediate_safety: 'immediate_safety',
        administrative: 'administrative'
      }, prefix: true

      enum :closure_type, {
        restorative_agreement: 'restorative_agreement',
        protective_action: 'protective_action',
        voluntary_resolution: 'voluntary_resolution',
        unsupported: 'unsupported',
        no_action: 'no_action'
      }, prefix: true

      belongs_to :report, class_name: 'BetterTogether::Report', inverse_of: :safety_case
      belongs_to :assigned_reviewer, class_name: 'BetterTogether::Person', optional: true

      has_many :actions, class_name: 'BetterTogether::Safety::Action', dependent: :destroy, inverse_of: :safety_case
      has_many :notes, class_name: 'BetterTogether::Safety::Note', dependent: :destroy, inverse_of: :safety_case
      has_many :agreements, class_name: 'BetterTogether::Safety::Agreement', dependent: :destroy, inverse_of: :safety_case

      validates :status, presence: true
      validates :lane, presence: true
      validates :category, presence: true
      validates :harm_level, presence: true
      validates :requested_outcome, presence: true

      scope :recent_first, -> { order(created_at: :desc) }
      scope :open_cases, -> { where.not(status: %w[resolved closed_no_action]) }

      delegate :reporter, :reportable, to: :report

      before_validation :set_default_lane, on: :create

      def urgent?
        harm_level == 'urgent'
      end

      def reporter_visible_status
        case status
        when 'submitted', 'triaged'
          'under_review'
        else
          status
        end
      end

      private

      def set_default_lane
        self.lane = if urgent? || retaliation_risk?
                      'immediate_safety'
                    elsif %w[spam_or_scam fraud impersonation misinformation].include?(category)
                      'administrative'
                    else
                      'restorative'
                    end
      end
    end
  end
end
