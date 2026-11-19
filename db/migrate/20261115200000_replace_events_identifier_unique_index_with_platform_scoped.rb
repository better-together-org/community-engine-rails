# frozen_string_literal: true

# Replace the bare unique index on better_together_events.identifier with a composite
# unique index on [identifier, platform_id], matching the posts and pages migrations.
# The Identifier concern already validates uniqueness per platform; only the database
# index still blocked the same identifier on two platforms.
class ReplaceEventsIdentifierUniqueIndexWithPlatformScoped < ActiveRecord::Migration[7.2]
  NEW_INDEX = 'idx_bt_events_on_identifier_platform_id'

  def up
    return unless table_exists?(:better_together_events)

    if index_exists?(:better_together_events, :identifier, unique: true)
      remove_index :better_together_events, :identifier
    end
    return if index_name_exists?(:better_together_events, NEW_INDEX)

    # Rows with a NULL platform_id stay covered by the model validation only.
    add_index :better_together_events, %i[identifier platform_id], unique: true,
                                                                   name: NEW_INDEX, where: 'platform_id IS NOT NULL'
  end

  def down
    return unless table_exists?(:better_together_events)

    remove_index :better_together_events, name: NEW_INDEX if index_name_exists?(:better_together_events, NEW_INDEX)
    return if index_exists?(:better_together_events, :identifier, unique: true)

    add_index :better_together_events, :identifier, unique: true
  end
end
