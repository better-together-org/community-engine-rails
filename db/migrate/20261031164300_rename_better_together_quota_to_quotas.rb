# frozen_string_literal: true

# "quota" pluralizes regularly to "quotas" in standard English (it entered English
# as a Latin adjective form, not a neuter -um noun like datum/quantum), but Rails'
# classical-Latin inflection rule matched it by pattern anyway, making
# "quota".pluralize a no-op. The original migration/model/association were built
# around that no-op rather than fighting it; config/initializers/inflections.rb now
# fixes the inflection instead, and this renames the table to match. A rename is
# metadata-only in Postgres - existing foreign key constraints from
# better_together_quota_usages/_reservations/_balances/_grants stay intact (they
# reference the table by OID, not by name).
class RenameBetterTogetherQuotaToQuotas < ActiveRecord::Migration[7.2]
  def change
    return unless table_exists?(:better_together_quota)
    return if table_exists?(:better_together_quotas)

    rename_table :better_together_quota, :better_together_quotas
  end
end
