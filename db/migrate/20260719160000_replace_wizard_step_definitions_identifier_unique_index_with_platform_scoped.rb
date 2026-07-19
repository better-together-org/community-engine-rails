# frozen_string_literal: true

# Replace the bare unique index on better_together_wizard_step_definitions.identifier
# with a composite unique index on [identifier, platform_id] — the same
# duplicate-identifier-across-platforms class of bug already fixed for pages
# (20260703171020) and posts (20260717140000), missed for this table when
# platform_id was added and backfilled from wizard.platform_id
# (20260607005002/20260607006002 — Phase 8 child tables) without a matching
# index update.
#
# This one is more than cosmetic: NewPlatformSetupWizardBuilder (this repo's
# new_platform_setup wizard) mints a brand-new Wizard + a full set of
# WizardStepDefinition rows (identifiers "welcome", "platform_identity",
# "domain", "steward_account", "review_and_launch") on every single
# provisioning run, by design — see that builder's class comment. With the
# old global unique index, only the very first platform ever provisioned
# through this wizard could succeed; every subsequent run's
# wizard_step_definitions.create!(identifier: "welcome", ...) would violate
# the bare unique index and raise ActiveRecord::RecordNotUnique/RecordInvalid,
# which NewPlatformSetupController#start silently caught and redirected to
# platforms_path with a flash alert — a production-severity defect that had
# no test coverage until this branch's Selenium-driven accessibility spec
# exercised two sequential real (non-transactional) provisioning runs and
# surfaced it. See NewPlatformSetupWizardBuilder.build, which now explicitly
# assigns platform_id: platform.id (the draft platform being provisioned) on
# every step definition it creates, matching how it already builds the
# Wizard row itself.
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
