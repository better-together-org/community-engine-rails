# frozen_string_literal: true

module BetterTogether
  # Explicit per-item x per-connection federation override. Layered on top of
  # the item's federation_visibility tri-state (Federatable concern): absence
  # of a grant for a (federatable, platform_connection) pair means "defer to
  # the tri-state"; a grant's status decides that specific connection only.
  #
  # Precedence (highest to lowest), enforced in
  # FederatedContentExportService#federation_consent_scoped:
  #   1. Connection doesn't allow this content type at all -- excluded, no grant can override.
  #   2. Item federation_visibility == no_federate -- excluded, no grant can override.
  #   3. An explicit grant exists for this connection -- 'denied' excludes, 'allowed' includes
  #      (bypassing the creator's global federate_content preference for this connection only).
  #   4. No grant for this connection -- falls through to the existing tri-state behavior.
  class FederationContentGrant < ApplicationRecord
    STATUSES = { allowed: 'allowed', denied: 'denied' }.freeze

    belongs_to :federatable, polymorphic: true
    belongs_to :platform_connection, class_name: 'BetterTogether::PlatformConnection'

    enum :status, STATUSES, default: :allowed

    validates :status, presence: true, inclusion: { in: STATUSES.values }
    validates :platform_connection_id, uniqueness: { scope: %i[federatable_type federatable_id] }
  end
end
