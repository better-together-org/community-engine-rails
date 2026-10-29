# frozen_string_literal: true

# A bare `t.bt_references :platform` inside `create_bt_table :quota` (no custom index
# name given) auto-generates "index_better_together_quotas_on_platform_id" — Rails 8.1.4's
# default reference-index naming pluralizes the enclosing table name even when an
# explicit `index: { name: ... }` option is also given (verified: the override is
# silently ignored for this specific non-polymorphic, singular-table case; every other
# explicitly-named index on this table, and the compound quota_* tables' own platform_id
# indexes, are unaffected). Rename it after the fact instead, which is unconditionally
# reliable regardless of the underlying cause.
class RenameBetterTogetherQuotaPlatformIndex < ActiveRecord::Migration[7.2]
  OLD_NAME = 'index_better_together_quotas_on_platform_id'
  NEW_NAME = 'index_bt_quota_on_platform'

  def change
    return unless index_name_exists?(:better_together_quota, OLD_NAME)

    rename_index :better_together_quota, OLD_NAME, NEW_NAME
  end
end
