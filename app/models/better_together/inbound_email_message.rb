# frozen_string_literal: true

module BetterTogether
  # Persists the canonical CE-side record for an inbound email after alias resolution.
  class InboundEmailMessage < ApplicationRecord
    self.table_name = 'better_together_inbound_email_messages'

    encrypts :subject
    encrypts :body_plain
    encrypts :content_screening_summary
    encrypts :content_security_records_json

    belongs_to :inbound_email,
               class_name: 'ActionMailbox::InboundEmail',
               inverse_of: false
    belongs_to :platform, class_name: 'BetterTogether::Platform', optional: true
    belongs_to :target, polymorphic: true, optional: true
    belongs_to :routed_record, polymorphic: true, optional: true

    ROUTE_KINDS = {
      community: 'community',
      agent: 'agent',
      membership_request: 'membership_request',
      unresolved: 'unresolved'
    }.freeze

    STATUSES = {
      received: 'received',
      routed: 'routed',
      rejected: 'rejected',
      failed: 'failed'
    }.freeze

    SCREENING_STATES = {
      pending: 'pending',
      passed: 'passed',
      held: 'held',
      error: 'error'
    }.freeze

    enum :route_kind, ROUTE_KINDS, prefix: true
    enum :status, STATUSES, prefix: true
    enum :screening_state, SCREENING_STATES, prefix: true

    validates :route_kind, inclusion: { in: route_kinds.values }
    validates :status, inclusion: { in: statuses.values }
    validates :screening_state, inclusion: { in: screening_states.values }
    validates :sender_email, presence: true
    validates :recipient_address, presence: true
    validates :recipient_local_part, presence: true
    validates :recipient_domain, presence: true
    validates :message_id, presence: true
    def content_security_records
      JSON.parse(content_security_records_json.presence || '[]')
    rescue JSON::ParserError
      []
    end

    def content_security_records=(records)
      self.content_security_records_json = Array(records).to_json
    end
  end
end
