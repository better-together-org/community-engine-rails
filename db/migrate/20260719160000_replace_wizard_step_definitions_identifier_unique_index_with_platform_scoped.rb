# frozen_string_literal: true

# Replace the bare unique index on identifier with a composite
# [identifier, platform_id] index — the same duplicate-identifier-across-
# platforms fix already applied to pages and posts. Without this,
# NewPlatformSetupWizardBuilder can only ever succeed once, since every
# provisioning run creates rows with the same identifiers.
class ReplaceWizardStepDefinitionsIdentifierUniqueIndexWithPlatformScoped < ActiveRecord::Migration[7.2]
  def change
    return unless table_exists?(:better_together_wizard_step_definitions) &&
                  index_exists?(:better_together_wizard_step_definitions, :identifier, unique: true)

    remove_index :better_together_wizard_step_definitions, :identifier

    # NOTE: The partial predicate (platform_id IS NOT NULL) means two records with
    # the same identifier and a NULL platform_id are NOT caught by this index.
    # The Identifier#validate_identifier_uniqueness model validation covers that gap.
    add_index :better_together_wizard_step_definitions, %i[identifier platform_id],
              unique: true,
              name: 'idx_bt_wizard_step_defs_on_identifier_platform_id',
              where: 'platform_id IS NOT NULL'
  end
end
