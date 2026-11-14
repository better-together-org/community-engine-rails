# frozen_string_literal: true

# Phase 7 — Backfill users.platform_id via active identification → person.platform_id.
# Backfill identifications.platform_id from the linked person.
class BackfillPlatformIdForUsersAndIdentifications < ActiveRecord::Migration[7.2]
  def up
    # Identifications: inherit from the person identity
    if column_exists?(:better_together_identifications, :platform_id)
      execute <<~SQL
        UPDATE better_together_identifications i
        SET    platform_id = p.platform_id
        FROM   better_together_people p
        WHERE  i.identity_type = 'BetterTogether::Person'
          AND  i.identity_id = p.id
          AND  i.platform_id IS NULL
          AND  p.platform_id IS NOT NULL
      SQL
    end

    # Users: inherit via their active identification → person
    return unless column_exists?(:better_together_users, :platform_id)

    execute <<~SQL
      UPDATE better_together_users u
      SET    platform_id = p.platform_id
      FROM   better_together_identifications i
      JOIN   better_together_people p
             ON p.id = i.identity_id
             AND i.identity_type = 'BetterTogether::Person'
      WHERE  i.agent_type = 'BetterTogether::User'
        AND  i.agent_id = u.id
        AND  i.active = TRUE
        AND  u.platform_id IS NULL
        AND  p.platform_id IS NOT NULL
    SQL
  end

  def down
    if column_exists?(:better_together_identifications, :platform_id)
      execute "UPDATE better_together_identifications SET platform_id = NULL"
    end

    return unless column_exists?(:better_together_users, :platform_id)

    execute "UPDATE better_together_users SET platform_id = NULL"
  end
end
