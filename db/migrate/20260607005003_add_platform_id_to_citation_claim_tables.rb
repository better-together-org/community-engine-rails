# frozen_string_literal: true

# Phase 8 — Citation, Claim, EvidenceLink, Joatu::ResponseLink.
class AddPlatformIdToCitationClaimTables < ActiveRecord::Migration[7.2]
  def change
    %w[
      better_together_citations
      better_together_claims
      better_together_evidence_links
      better_together_joatu_response_links
    ].each do |table|
      next if column_exists?(table, :platform_id)

      add_reference table, :platform,
                    type: :uuid, null: true,
                    foreign_key: { to_table: :better_together_platforms },
                    index: true
    end
  end
end
