# frozen_string_literal: true

# Adds platform tracking to this compliance audit table. Some historical/automated
# rows have no derivable platform at all (e.g. a direct hard-deletion with no
# person_deletion_request), so this column stays nullable permanently — do not
# force NOT NULL.
class AddPlatformToBetterTogetherPersonPurgeAudits < ActiveRecord::Migration[7.2]
  def up
    unless column_exists?(:better_together_person_purge_audits, :platform_id)
      add_reference :better_together_person_purge_audits, :platform,
                    type: :uuid, null: true,
                    foreign_key: { to_table: :better_together_platforms }, index: true
    end

    # Raw SQL, not `.update!` — the model's before_update immutability guard blocks
    # normal updates to persisted audit rows.
    execute <<~SQL
      UPDATE better_together_person_purge_audits ppa
      SET    platform_id = pdr.platform_id
      FROM   better_together_person_deletion_requests pdr
      WHERE  ppa.person_deletion_request_id = pdr.id
        AND  ppa.platform_id IS NULL
        AND  pdr.platform_id IS NOT NULL
    SQL

    execute <<~SQL
      UPDATE better_together_person_purge_audits ppa
      SET    platform_id = p.platform_id
      FROM   better_together_people p
      WHERE  ppa.person_id = p.id
        AND  ppa.platform_id IS NULL
        AND  p.platform_id IS NOT NULL
    SQL
  end

  def down
    # Clears backfilled values rather than dropping the column/reference, so this
    # stays safe to call from specs recreating pre-backfill state (avoids
    # ActiveRecord column-cache invalidation from dropping and re-adding a column
    # mid-process).
    return unless column_exists?(:better_together_person_purge_audits, :platform_id)

    execute 'UPDATE better_together_person_purge_audits SET platform_id = NULL'
  end
end
