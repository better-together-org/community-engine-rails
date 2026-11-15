# frozen_string_literal: true

# One row per record a seed packet planted on a platform: which packet and version wrote it, under what
# key, and a fingerprint plus field snapshot taken right after the write. Replaces reading provenance back
# out of SeedPlanting.result and lets any record be traced to the packet that planted it.
class CreateBetterTogetherSeedProvenances < ActiveRecord::Migration[7.2]
  UNIQUE_INDEX = 'index_bt_seed_provenances_on_platform_packet_record'
  RECORD_INDEX = 'index_bt_seed_provenances_on_record'

  def change
    unless table_exists?(:better_together_seed_provenances)
      create_bt_table :seed_provenances do |t|
        t.references :platform, null: false, type: :uuid, foreign_key: { to_table: :better_together_platforms }
        t.references :seed, null: true, type: :uuid, foreign_key: { to_table: :better_together_seeds }
        t.references :seed_planting, null: true, type: :uuid, foreign_key: { to_table: :better_together_seed_plantings }
        t.string :packet_id, null: false
        t.string :packet_version
        t.string :record_type, null: false
        t.string :record_key, null: false
        t.string :record_class, null: false
        t.uuid :record_id, null: false
        t.string :fingerprint, null: false
        t.jsonb :snapshot, null: false, default: {}
      end
    end

    unless index_name_exists?(:better_together_seed_provenances, UNIQUE_INDEX)
      add_index :better_together_seed_provenances, %i[platform_id packet_id record_type record_key],
                unique: true, name: UNIQUE_INDEX
    end
    return if index_name_exists?(:better_together_seed_provenances, RECORD_INDEX)

    add_index :better_together_seed_provenances, %i[record_class record_id], name: RECORD_INDEX
  end
end
