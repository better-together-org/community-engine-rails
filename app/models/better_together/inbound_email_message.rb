# frozen_string_literal: true

module BetterTogether
  # Persists the canonical CE-side record for an inbound email after alias resolution.
  class InboundEmailMessage < ApplicationRecord
    self.table_name = 'better_together_inbound_email_messages'

    encrypts :subject
    encrypts :body_plain

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

    enum :route_kind, ROUTE_KINDS, prefix: true
    enum :status, STATUSES, prefix: true

    validates :route_kind, inclusion: { in: route_kinds.values }
    validates :status, inclusion: { in: statuses.values }
    validates :sender_email, presence: true
    validates :recipient_address, presence: true
    validates :recipient_local_part, presence: true
    validates :recipient_domain, presence: true
    validates :message_id, presence: true
  end
end
