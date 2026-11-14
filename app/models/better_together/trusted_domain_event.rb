# frozen_string_literal: true

module BetterTogether
  # Append-only audit entry: a trusted domain was added, changed or removed, or an account was created
  # (or granted membership) through one. Snapshots the domain and role so entries outlive the domain.
  class TrustedDomainEvent < ApplicationRecord
    EVENT_TYPES = %w[
      domain_added domain_updated domain_removed
      account_created membership_granted membership_request_approved grant_rate_limited
    ].freeze
    VIAS = %w[oauth password_registration membership_request steward].freeze

    belongs_to :platform, class_name: '::BetterTogether::Platform'
    belongs_to :platform_trusted_domain, class_name: '::BetterTogether::PlatformTrustedDomain', optional: true
    belongs_to :actor, class_name: '::BetterTogether::Person', optional: true
    belongs_to :subject, class_name: '::BetterTogether::Person', optional: true

    validates :event_type, inclusion: { in: EVENT_TYPES }
    validates :via, inclusion: { in: VIAS }, allow_nil: true
    validates :domain, presence: true

    scope :newest_first, -> { order(created_at: :desc) }
    scope :account_grants, -> { where(event_type: %w[account_created membership_granted membership_request_approved]) }

    before_update { raise ActiveRecord::ReadOnlyRecord, 'trusted domain events are append-only' }
    before_destroy { raise ActiveRecord::ReadOnlyRecord, 'trusted domain events are append-only' }
  end
end
