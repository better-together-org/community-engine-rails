# frozen_string_literal: true

# Consolidated re-add of the Claim/Citation/EvidenceLink schema (originally
# 20260404233000 + 20260404234500, dropped by
# 20260918041500_remove_orphaned_evidence_foundation_schema). Written fresh
# rather than restoring the 2 original files, since their version numbers
# are already marked "up" in every host's schema_migrations and would no-op
# there -- same reasoning as the e2e reintegration's consolidated migration.
#
# NOTE: recreates the tables exactly as they existed before removal (no
# platform_id) to match the reverted model layer, which also predates the
# platform-scoping work. Aligning these tables with the current
# platform-isolation convention is reintegration work, not covered here.
class ReintroduceEvidenceFoundationSchema < ActiveRecord::Migration[7.2]
  def up
    unless table_exists?(:better_together_citations)
      create_table :better_together_citations, id: :uuid do |t|
        t.references :citeable, polymorphic: true, null: false, type: :uuid, index: { name: 'idx_bt_citations_on_citeable' }
        t.references :creator, foreign_key: { to_table: :better_together_people }, type: :uuid
        t.integer :position
        t.string :reference_key, null: false
        t.string :source_kind, null: false, default: 'webpage'
        t.string :title, null: false
        t.string :source_author
        t.string :publisher
        t.string :source_url
        t.string :locator
        t.date :published_on
        t.date :accessed_on
        t.text :excerpt
        t.text :rights_notes
        t.jsonb :metadata, null: false, default: {}
        t.timestamps
      end
      add_index :better_together_citations,
                %i[citeable_type citeable_id reference_key],
                unique: true,
                name: 'idx_bt_citations_on_citeable_and_reference_key'
    end

    unless table_exists?(:better_together_claims)
      create_table :better_together_claims, id: :uuid do |t|
        t.references :claimable, polymorphic: true, null: false, type: :uuid, index: { name: 'idx_bt_claims_on_claimable' }
        t.references :creator, foreign_key: { to_table: :better_together_people }, type: :uuid
        t.integer :position
        t.string :claim_key, null: false
        t.text :statement, null: false
        t.text :selector
        t.string :review_status, null: false, default: 'draft'
        t.jsonb :metadata, null: false, default: {}
        t.timestamps
      end
      add_index :better_together_claims,
                %i[claimable_type claimable_id claim_key],
                unique: true,
                name: 'idx_bt_claims_on_claimable_and_claim_key'
    end

    return if table_exists?(:better_together_evidence_links)

    create_table :better_together_evidence_links, id: :uuid do |t|
      t.references :claim, null: false, foreign_key: { to_table: :better_together_claims }, type: :uuid
      t.references :citation, null: false, foreign_key: { to_table: :better_together_citations }, type: :uuid
      t.references :creator, foreign_key: { to_table: :better_together_people }, type: :uuid
      t.integer :position
      t.string :relation_type, null: false, default: 'supports'
      t.string :locator
      t.text :quoted_text
      t.text :editor_note
      t.string :review_status, null: false, default: 'draft'
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :better_together_evidence_links,
              %i[claim_id citation_id relation_type],
              unique: true,
              name: 'idx_bt_evidence_links_on_claim_citation_relation'
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
