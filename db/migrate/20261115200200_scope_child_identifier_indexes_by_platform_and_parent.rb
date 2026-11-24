# frozen_string_literal: true

# Children keep their identifier unique inside their parent and platform, and a child's platform
# follows its parent's. Backfills blank child platform ids from the parent first.
class ScopeChildIdentifierIndexesByPlatformAndParent < ActiveRecord::Migration[7.2]
  PARENT_SCOPED = {
    better_together_agreement_terms: [:agreement_id, 'better_together_agreements', 'idx_bt_agreement_terms_on_platform_parent_identifier'],
    better_together_checklist_items: [:checklist_id, 'better_together_checklists', 'idx_bt_checklist_items_on_platform_parent_identifier']
  }.freeze
  BACKFILL = {
    better_together_wizard_steps: [:wizard_id, 'better_together_wizards'],
    better_together_wizard_step_definitions: [:wizard_id, 'better_together_wizards']
  }.freeze
  OLD_STEP_INDEX = 'index_unique_wizard_steps'
  NEW_STEP_INDEX = 'idx_bt_wizard_steps_unique_open_per_platform'

  def up
    PARENT_SCOPED.each { |table, (foreign_key, parent, name)| scope_by_parent(table, foreign_key, parent, name) }
    BACKFILL.each { |table, (foreign_key, parent)| backfill(table, foreign_key, parent) if table_exists?(table) }
    replace_step_index
  end

  def down
    PARENT_SCOPED.each do |table, (_fk, _parent, name)|
      next unless table_exists?(table)

      remove_index table, name: name if index_name_exists?(table, name)
      add_index table, :identifier, unique: true unless index_exists?(table, :identifier, unique: true)
    end
    return unless table_exists?(:better_together_wizard_steps)

    remove_index :better_together_wizard_steps, name: NEW_STEP_INDEX if index_name_exists?(:better_together_wizard_steps, NEW_STEP_INDEX)
    restore_step_index
  end

  private

  def scope_by_parent(table, foreign_key, parent, name)
    return unless table_exists?(table) && column_exists?(table, :platform_id)

    backfill(table, foreign_key, parent)
    remove_index table, :identifier if index_exists?(table, :identifier, unique: true)
    return if index_name_exists?(table, name)

    add_index table, [:platform_id, foreign_key, :identifier], unique: true, name: name,
                                                               where: 'platform_id IS NOT NULL'
  end

  def backfill(table, foreign_key, parent)
    return unless table_exists?(parent) && column_exists?(table, :platform_id)

    execute <<~SQL.squish
      UPDATE #{table} SET platform_id = p.platform_id FROM #{parent} p
      WHERE #{table}.#{foreign_key} = p.id AND #{table}.platform_id IS NULL AND p.platform_id IS NOT NULL
    SQL
  end

  # Same open-step rule as before, with the platform added to the key.
  def replace_step_index
    return unless table_exists?(:better_together_wizard_steps)

    remove_index :better_together_wizard_steps, name: OLD_STEP_INDEX if index_name_exists?(:better_together_wizard_steps, OLD_STEP_INDEX)
    return if index_name_exists?(:better_together_wizard_steps, NEW_STEP_INDEX)

    add_index :better_together_wizard_steps, %i[platform_id wizard_id identifier creator_id],
              unique: true, name: NEW_STEP_INDEX, where: 'completed IS FALSE AND platform_id IS NOT NULL'
    add_index :better_together_wizard_steps, %i[wizard_id identifier creator_id],
              unique: true, name: OLD_STEP_INDEX, where: 'completed IS FALSE AND platform_id IS NULL'
  end

  def restore_step_index
    remove_index :better_together_wizard_steps, name: OLD_STEP_INDEX if index_name_exists?(:better_together_wizard_steps, OLD_STEP_INDEX)
    add_index :better_together_wizard_steps, %i[wizard_id identifier creator_id],
              unique: true, name: OLD_STEP_INDEX, where: 'completed IS FALSE'
  end
end
