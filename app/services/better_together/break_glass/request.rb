# frozen_string_literal: true

module BetterTogether
  module BreakGlass
    # Opens a grant. Holding the sealed manage_break_glass_disclosure permission on the record's platform is
    # required and checked again here, so no caller can skip it. A normal grant waits DEFAULT_DELAY before it can
    # be used; an emergency grant is usable at once but needs a reason code and is flagged in the audit trail.
    class Request
      PERMISSION = 'manage_break_glass_disclosure'

      def self.call(...)
        new(...).call
      end

      def initialize(requester:, subject:, reason:, grantee: nil, emergency: false, reason_code: nil, # rubocop:disable Metrics/ParameterLists
                     duration: BreakGlassGrant::DEFAULT_DURATION)
        @requester = requester
        @subject = subject
        @reason = reason
        @grantee = grantee || requester
        @emergency = emergency
        @reason_code = reason_code
        @duration = duration
      end

      def call
        raise NotAuthorized unless authorized?

        BreakGlassGrant.transaction do
          grant = BreakGlassGrant.create!(attributes)
          grant.events.create!(event_type: 'requested', actor: @requester, platform: grant.platform,
                               detail: audit_detail(grant))
          grant
        end
      end

      private

      def authorized?
        @requester.present? && @subject.respond_to?(:platform) && @subject.platform.present? &&
          @requester.permitted_to?(PERMISSION, @subject.platform)
      end

      def attributes
        available_at = @emergency ? Time.current : Time.current + BreakGlassGrant::DEFAULT_DELAY
        { subject: @subject, grantee: @grantee, requested_by: @requester, reason: @reason,
          reason_code: @reason_code, emergency: @emergency, platform: @subject.platform, status: 'requested',
          available_at:, expires_at: available_at + @duration }
      end

      def audit_detail(grant)
        { emergency: grant.emergency, reason_code: grant.reason_code, available_at: grant.available_at,
          expires_at: grant.expires_at, subject_type: grant.subject_type, subject_id: grant.subject_id }
      end
    end
  end
end
