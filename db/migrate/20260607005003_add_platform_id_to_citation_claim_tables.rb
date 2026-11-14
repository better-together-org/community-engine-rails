# frozen_string_literal: true

# Phase 8 — Joatu::ResponseLink.
#
# Originally also added platform_id to better_together_citations/claims/
# evidence_links, but those tables (and the Citation/Claim/EvidenceLink
# models that used them) were removed from this release as part of the
# Evidence-foundation carve-out — see docs/developers/systems/
# pr_1494_scope_consolidation.md. Only the pre-existing, stable
# Joatu::ResponseLink table still needs its platform_id.
class AddPlatformIdToCitationClaimTables < ActiveRecord::Migration[7.2]
  def change
    return if column_exists?(:better_together_joatu_response_links, :platform_id)

    add_reference :better_together_joatu_response_links, :platform,
                  type: :uuid, null: true,
                  foreign_key: { to_table: :better_together_platforms },
                  index: true
  end
end
