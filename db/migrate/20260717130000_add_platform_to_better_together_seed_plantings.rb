# frozen_string_literal: true

# SeedPlanting has no reliable derivable platform for many real call paths
# (automated/federated tending jobs run with no request context), so this column
# stays nullable permanently — no backfill for existing rows, and no NOT NULL
# tightening. A NULL platform_id here is the correct, expected outcome for
# system-initiated plantings, not a residual gap.
class AddPlatformToBetterTogetherSeedPlantings < ActiveRecord::Migration[7.2]
  def up
    return if column_exists?(:better_together_seed_plantings, :platform_id)

    add_reference :better_together_seed_plantings, :platform,
                  type: :uuid, null: true,
                  foreign_key: { to_table: :better_together_platforms }, index: true
  end

  def down
    return unless column_exists?(:better_together_seed_plantings, :platform_id)

    existing_fk = foreign_keys(:better_together_seed_plantings).find do |fk|
      fk.to_table == 'better_together_platforms'
    end
    remove_foreign_key :better_together_seed_plantings, name: existing_fk.name if existing_fk
    remove_column :better_together_seed_plantings, :platform_id
  end
end
