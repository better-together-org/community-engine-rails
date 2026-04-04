# frozen_string_literal: true

module BetterTogether
  # Records immutable agreement acceptance evidence without storing identifying request metadata.
  class AgreementAcceptanceRecorder
    def self.record!(...)
      new(...).record!
    end

    def initialize(agreement:, participant: nil, person: nil, acceptance_method:, accepted_at: Time.current, context: {})
      @agreement = agreement
      @participant = participant || person
      @acceptance_method = acceptance_method
      @accepted_at = accepted_at
      @context = context
    end

    def record!
      AgreementParticipant.create!(
        agreement:,
        participant:,
        accepted_at:,
        acceptance_method:,
        audit_context: normalized_audit_context
      )
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
