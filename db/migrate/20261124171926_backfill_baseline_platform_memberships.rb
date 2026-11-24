# frozen_string_literal: true

# Gives every account on a local platform the baseline platform_member membership on its own platform.
#
# BackfillHostPlatformMemberships (20260321000002) covered the people who existed when platform memberships
# arrived. Anyone who registered since then, on any local platform, only got a community membership. This
# adds the missing row.
#
#   - One row per account: the person behind each user, on the platform the user belongs to (users.platform_id).
#   - Role: that platform's own platform_member role. A platform that has no such role is skipped, never
#     given another platform's role or an admin-tier fallback.
#   - Status: active when the account's email is confirmed, pending otherwise. Confirming the address
#     activates a pending membership, as it does for community memberships.
#   - People who already hold platform_member on the platform, and remote platforms, are left alone.
#     Other roles a person holds (steward, manager) stay as they are; roles stack.
#
# Rows are inserted directly, so no "you were added" notification goes to people who registered long ago.
# Idempotent: a second run inserts nothing.
class BackfillBaselinePlatformMemberships < ActiveRecord::Migration[7.2]
  def up
    return unless tables_ready?

    inserted = exec_update(<<~SQL.squish, 'backfill baseline platform memberships')
      INSERT INTO better_together_person_platform_memberships
             (id, member_id, joinable_id, role_id, status, lock_version, created_at, updated_at)
      SELECT DISTINCT ON (i.identity_id, pl.id)
             gen_random_uuid(), i.identity_id, pl.id, r.id,
             CASE WHEN u.confirmed_at IS NOT NULL THEN 'active' ELSE 'pending' END,
             0, NOW(), NOW()
      FROM   better_together_users u
      JOIN   better_together_identifications i
             ON  i.agent_type    = 'BetterTogether::User'
             AND i.agent_id      = u.id
             AND i.identity_type = 'BetterTogether::Person'
             AND i.active        = TRUE
      JOIN   better_together_platforms pl
             ON  pl.id = u.platform_id
             AND pl.locality = 'local'
      JOIN   better_together_roles r
             ON  r.platform_id   = pl.id
             AND r.identifier    = 'platform_member'
             AND r.resource_type = 'BetterTogether::Platform'
      WHERE  NOT EXISTS (
               SELECT 1
               FROM   better_together_person_platform_memberships m
               WHERE  m.member_id   = i.identity_id
                 AND  m.joinable_id = pl.id
                 AND  m.role_id     = r.id
             )
      ORDER BY i.identity_id, pl.id, u.created_at
    SQL

    say "baseline platform memberships added: #{inserted}"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def tables_ready?
    %i[better_together_users better_together_identifications better_together_platforms
       better_together_roles better_together_person_platform_memberships].all? { |table| table_exists?(table) } &&
      column_exists?(:better_together_users, :platform_id) &&
      column_exists?(:better_together_roles, :platform_id)
  end
end
