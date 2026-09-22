# frozen_string_literal: true

module BetterTogether
  # Records immutable agreement acceptance evidence without storing identifying request metadata.
  class AgreementAcceptanceRecorder
    def self.record!(...)
      new(...).record!
    end

    def initialize(agreement:, acceptance_method:, participant: nil, person: nil, accepted_at: Time.current, context: {}) # rubocop:todo Metrics/ParameterLists
      @agreement = agreement
      @participant = participant || person
      @acceptance_method = acceptance_method
      @accepted_at = accepted_at
      @context = context
    end

    def record!
      agreement_participant = AgreementParticipant.find_or_initialize_by(
        agreement:,
        participant:
      )

      agreement_participant.assign_attributes(
        accepted_at:,
        acceptance_method:,
        audit_context: normalized_audit_context
      )
      agreement_participant.save!
      agreement_participant
    end

    private

    attr_reader :accepted_at, :acceptance_method, :agreement, :context, :participant

    def normalized_audit_context
      base_context = context.except(:request).to_h.deep_stringify_keys
      request = context[:request]
      request_context = {
        'locale' => I18n.locale.to_s.presence,
        'request_id' => request&.request_id.presence,
        'source_path' => request&.fullpath.presence
      }.compact

      base_context.merge(request_context)
    end
  end
end
