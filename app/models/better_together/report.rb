# frozen_string_literal: true

module BetterTogether
  # Record of a person reporting inappropriate content or users
  class Report < ApplicationRecord
    ALLOWED_REPORTABLES = [
      'BetterTogether::Person',
      'BetterTogether::Post',
      'BetterTogether::Event',
      'BetterTogether::Message',
      'BetterTogether::Joatu::Offer',
      'BetterTogether::Joatu::Request',
      'BetterTogether::Joatu::Agreement'
    ].freeze

    # Intake fields should be chosen by the reporter, not silently filled from DB defaults.
    attribute :category, :string
    attribute :harm_level, :string
    attribute :requested_outcome, :string

    enum :category, {
      harassment: 'harassment',
      hate_speech: 'hate_speech',
      discrimination: 'discrimination',
      spam_or_scam: 'spam_or_scam',
      privacy_violation: 'privacy_violation',
      misinformation: 'misinformation',
      boundary_violation: 'boundary_violation',
      fraud: 'fraud',
      impersonation: 'impersonation',
      other: 'other'
    }, prefix: true

    enum :harm_level, {
      low: 'low',
      medium: 'medium',
      high: 'high',
      urgent: 'urgent'
    }, prefix: true

    enum :requested_outcome, {
      boundary_support: 'boundary_support',
      mediated_conversation: 'mediated_conversation',
      community_accountability: 'community_accountability',
      content_review: 'content_review',
      temporary_protection: 'temporary_protection',
      other: 'other'
    }, prefix: true

    belongs_to :reporter, class_name: 'BetterTogether::Person', inverse_of: :reports_made
    belongs_to :reportable, polymorphic: true
    has_one :safety_case, class_name: 'BetterTogether::Safety::Case', dependent: :destroy, inverse_of: :report

    validates :reason, presence: true
    validates :category, presence: true
    validates :harm_level, presence: true
    validates :requested_outcome, presence: true
    validates :reportable_type, inclusion: { in: ALLOWED_REPORTABLES }
    validates :reportable_id, uniqueness: {
      scope: %i[reporter_id reportable_type],
      message: ->(_report, _data) { I18n.t('better_together.reports.errors.already_reported_by_you') }
    }

    after_create_commit :ensure_safety_case!

    def case_status
      safety_case&.status || 'submitted'
    end

    private

    def ensure_safety_case!
      return if safety_case.present?

      create_safety_case!(
        category:,
        harm_level:,
        requested_outcome:,
        retaliation_risk: retaliation_risk || false,
        consent_to_contact: consent_to_contact.nil? || consent_to_contact,
        consent_to_restorative_process: consent_to_restorative_process || false
      )
    end
  end
end
