# frozen_string_literal: true

class CreateBetterTogetherClaimsAndEvidenceLinks < ActiveRecord::Migration[7.1]
  def change
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
    end

    unless index_exists?(:better_together_claims,
                         %i[claimable_type claimable_id claim_key],
                         unique: true,
                         name: 'idx_bt_claims_on_claimable_and_claim_key')
      add_index :better_together_claims,
                %i[claimable_type claimable_id claim_key],
                unique: true,
                name: 'idx_bt_claims_on_claimable_and_claim_key'
    end

    unless table_exists?(:better_together_evidence_links)
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
    end

    unless index_exists?(:better_together_evidence_links,
                         %i[claim_id citation_id relation_type],
                         unique: true,
                         name: 'idx_bt_evidence_links_on_claim_citation_relation')
      add_index :better_together_evidence_links,
                %i[claim_id citation_id relation_type],
                unique: true,
                name: 'idx_bt_evidence_links_on_claim_citation_relation'
    end
  end
end
