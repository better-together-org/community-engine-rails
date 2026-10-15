# frozen_string_literal: true

# Drops the Claim/Citation/EvidenceLink schema left behind by the
# Evidence-foundation carve-out (7909eea17, "carve Evidence-foundation
# (Claim/Citation) out of the release"). That commit removed the models,
# controllers, views, and the 2 creation migration files, but never shipped
# a migration to actually drop the tables -- they are still present and
# fully populated-capable on every host that ran the original migrations,
# orphaned from the current codebase (no model references them). Mirrors
# the e2e removal's cleanup migration (20260911205151).
class RemoveOrphanedEvidenceFoundationSchema < ActiveRecord::Migration[7.2]
  def up
    drop_table :better_together_evidence_links, if_exists: true
    drop_table :better_together_claims, if_exists: true
    drop_table :better_together_citations, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
