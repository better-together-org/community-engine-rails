# frozen_string_literal: true

# Seeds were unique on (type, identifier) across the whole database, so two platforms could not
# store the same seed. A nullable platform_id scopes a seed to one platform; seeds without one stay
# global (federation and CE builders), unique among themselves.
class AddPlatformToBetterTogetherSeeds < ActiveRecord::Migration[7.2]
  GLOBAL_INDEX = 'index_better_together_seeds_global_type_and_identifier'
  PLATFORM_INDEX = 'index_better_together_seeds_platform_type_and_identifier'

  OLD_INDEXES = %w[index_better_together_seeds_on_identifier index_better_together_seeds_on_type_and_identifier].freeze

  def up
    unless column_exists?(:better_together_seeds, :platform_id)
      add_reference :better_together_seeds, :platform, type: :uuid, null: true,
                                                       foreign_key: { to_table: :better_together_platforms }, index: true
    end

    OLD_INDEXES.each do |name|
      remove_index :better_together_seeds, name: name if index_name_exists?(:better_together_seeds, name)
    end

    unless index_name_exists?(:better_together_seeds, GLOBAL_INDEX)
      add_index :better_together_seeds, %i[type identifier], unique: true, where: 'platform_id IS NULL', name: GLOBAL_INDEX
    end
    return if index_name_exists?(:better_together_seeds, PLATFORM_INDEX)

    add_index :better_together_seeds, %i[type identifier platform_id], unique: true, where: 'platform_id IS NOT NULL',
                                                                       name: PLATFORM_INDEX
  end

  def down
    remove_index :better_together_seeds, name: PLATFORM_INDEX if index_name_exists?(:better_together_seeds, PLATFORM_INDEX)
    remove_index :better_together_seeds, name: GLOBAL_INDEX if index_name_exists?(:better_together_seeds, GLOBAL_INDEX)
    remove_reference :better_together_seeds, :platform, foreign_key: { to_table: :better_together_platforms } if column_exists?(
      :better_together_seeds, :platform_id
    )

    add_index :better_together_seeds, :identifier, unique: true, name: 'index_better_together_seeds_on_identifier'
    add_index :better_together_seeds, %i[type identifier], unique: true, name: 'index_better_together_seeds_on_type_and_identifier'
  end
end
