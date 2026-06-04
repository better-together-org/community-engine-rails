# frozen_string_literal: true

require 'digest'

module BetterTogether
  # Statements agreed upon by its participants
  class Agreement < ApplicationRecord # rubocop:todo Metrics/ClassLength
    include Citable
    include Claimable
    include Creatable
    include Identifier
    include Privacy
    include Protected

    has_many :agreement_participants, class_name: 'BetterTogether::AgreementParticipant', dependent: :destroy
    has_many :agreement_terms, -> { positioned }, class_name: 'BetterTogether::AgreementTerm'
    # Optional link to a Page: when set, the page's content will be shown
    # instead of the agreement's terms in the public agreement view.
    belongs_to :page, class_name: 'BetterTogether::Page', optional: true
    has_many :participants, through: :agreement_participants, source: :person

    accepts_nested_attributes_for :agreement_terms, reject_if: :all_blank, allow_destroy: true

    before_validation :apply_default_consent_metadata

    AGREEMENT_KINDS = {
      policy_consent: 'policy_consent',
      publishing_consent: 'publishing_consent',
      transactional_agreement: 'transactional_agreement'
    }.freeze

    REQUIRED_FOR_VALUES = {
      none: 'none',
      registration: 'registration',
      first_publish: 'first_publish'
    }.freeze

    LIFECYCLE_STATES = {
      draft: 'draft',
      active: 'active',
      retired: 'retired'
    }.freeze

    translates :title, type: :string
    translates :description, backend: :action_text

    attribute :agreement_kind, :string, default: AGREEMENT_KINDS[:policy_consent]
    attribute :required_for, :string, default: REQUIRED_FOR_VALUES[:none]
    attribute :active_for_consent, :boolean, default: true
    attribute :lifecycle_state, :string, default: LIFECYCLE_STATES[:active]
    attribute :requires_reacceptance, :boolean, default: false
    attribute :change_summary, :string

    enum :agreement_kind, AGREEMENT_KINDS, prefix: true
    enum :required_for, REQUIRED_FOR_VALUES, prefix: true
    enum :lifecycle_state, LIFECYCLE_STATES, prefix: true

    validates :agreement_kind, presence: true, inclusion: { in: AGREEMENT_KINDS.values }
    validates :required_for, presence: true, inclusion: { in: REQUIRED_FOR_VALUES.values }
    validates :lifecycle_state, presence: true, inclusion: { in: LIFECYCLE_STATES.values }

    scope :accepted_by, lambda { |participant|
      joins(:agreement_participants)
        .merge(BetterTogether::AgreementParticipant.accepted.for_participant(participant))
        .distinct
    }
    scope :active_lifecycle, -> { where(lifecycle_state: LIFECYCLE_STATES[:active]) }
    scope :active_for_consent, -> { active_lifecycle.where(active_for_consent: true) }
    scope :required_for_registration, -> { active_for_consent.where(required_for: REQUIRED_FOR_VALUES[:registration]) }
    scope :required_for_first_publish, -> { active_for_consent.where(required_for: REQUIRED_FOR_VALUES[:first_publish]) }
    scope :ordered_for_consent, lambda {
      order(Arel.sql("CASE identifier
                        WHEN 'terms_of_service' THEN 0
                        WHEN 'privacy_policy' THEN 1
                        WHEN 'code_of_conduct' THEN 2
                        WHEN 'content_publishing_agreement' THEN 3
                        ELSE 99
                      END"), :created_at)
    }

    def acceptance_audit_snapshot
      snapshot_attributes.merge('terms' => agreement_term_snapshots)
    end

    def acceptance_content_digest
      Digest::SHA256.hexdigest(acceptance_audit_snapshot.to_json)
    end

    def accepted_participants
      agreement_participants.accepted.includes(:participant)
    end

    def latest_acceptance_for(participant)
      agreement_participants.accepted.for_participant(participant).order(accepted_at: :desc).first
    end

    def current_acceptance_for(participant)
      acceptance = latest_acceptance_for(participant)
      return unless acceptance
      return acceptance unless stale_acceptance?(acceptance)

      nil
    end

    def stale_acceptance_for(participant)
      acceptance = latest_acceptance_for(participant)
      return unless acceptance
      return unless stale_acceptance?(acceptance)

      acceptance
    end

    def accepted_by?(participant)
      current_acceptance_for(participant).present?
    end

    def consent_required_for?(participant)
      active_for_consent? && current_acceptance_for(participant).blank?
    end

    def lifecycle_display_name
      lifecycle_state.to_s.humanize
    end

    def required_for_display_name
      return 'Not required by default' if required_for_none?

      required_for.to_s.humanize
    end

    def self.permitted_attributes(id: false, destroy: false)
      super + %i[page_id agreement_kind required_for active_for_consent lifecycle_state requires_reacceptance change_summary]
    end

    def self.registration_consent_records
      agreements = required_for_registration.ordered_for_consent.to_a
      return agreements if agreements.present?

      where(identifier: %w[terms_of_service privacy_policy code_of_conduct]).ordered_for_consent.to_a
    end

    def self.first_publish_consent_record
      required_for_first_publish.ordered_for_consent.first || find_by(identifier: 'content_publishing_agreement')
    end

    slugged :title

    private

    def apply_default_consent_metadata # rubocop:todo Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      self.active_for_consent = true if active_for_consent.nil?
      self.lifecycle_state ||= LIFECYCLE_STATES[:active]
      self.requires_reacceptance = false if requires_reacceptance.nil?

      case identifier.to_s
      when 'privacy_policy', 'terms_of_service', 'code_of_conduct'
        self.agreement_kind ||= AGREEMENT_KINDS[:policy_consent]
        self.required_for ||= REQUIRED_FOR_VALUES[:registration]
      when 'content_publishing_agreement'
        self.agreement_kind ||= AGREEMENT_KINDS[:publishing_consent]
        self.required_for ||= REQUIRED_FOR_VALUES[:first_publish]
      else
        self.agreement_kind ||= AGREEMENT_KINDS[:policy_consent]
        self.required_for ||= REQUIRED_FOR_VALUES[:none]
      end
    end

    def snapshot_attributes
      {
        identifier: identifier.to_s,
        title: title.to_s,
        description: description.to_plain_text.to_s,
        page_id: page_id,
        updated_at: updated_at&.utc&.iso8601(6)
      }.deep_stringify_keys
    end

    def agreement_term_snapshots
      agreement_terms.map do |term|
        {
          'position' => term.position,
          'summary' => term.summary.to_s,
          'content' => term.content.to_plain_text.to_s
        }
      end
    end

    def stale_acceptance?(acceptance)
      requires_reacceptance? && acceptance.agreement_content_digest != acceptance_content_digest
    end
  end
end
