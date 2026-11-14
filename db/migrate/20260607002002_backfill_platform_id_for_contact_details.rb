# frozen_string_literal: true

# Phase 6 — Backfill platform_id for ContactDetail from Person owners.
class BackfillPlatformIdForContactDetails < ActiveRecord::Migration[7.2]
  def up
    return unless column_exists?(:better_together_contact_details, :platform_id)
    # people.platform_id is added in 20260607003001, which runs after this migration.
    # Guard so this is a no-op when running in sequence; the actual backfill is
    # deferred to 20260607004001 (backfill_platform_id_for_people) which runs after
    # people have their platform_id populated.
    return unless column_exists?(:better_together_people, :platform_id)

    execute <<~SQL
      UPDATE better_together_contact_details cd
      SET    platform_id = p.platform_id
      FROM   better_together_people p
      WHERE  cd.contactable_type = 'BetterTogether::Person'
        AND  cd.contactable_id = p.id
        AND  cd.platform_id IS NULL
        AND  p.platform_id IS NOT NULL
    SQL
  end

  def down
    return unless column_exists?(:better_together_contact_details, :platform_id)

    execute "UPDATE better_together_contact_details SET platform_id = NULL"
  end
end
