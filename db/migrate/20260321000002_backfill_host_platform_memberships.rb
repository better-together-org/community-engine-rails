# frozen_string_literal: true

# Backfill PersonPlatformMembership records for people who pre-date the
# multi-tenant architecture.
#
# Before the multi-tenant branch, there was no PersonPlatformMembership table.
# When this branch is deployed to an existing CE instance every current person
# has used the platform without a platform membership row.  Without a backfill
# those people would have no role on the host platform and would lose access to
# platform-scoped features.
#
# Backfill strategy:
#   - Resolve the host platform (host = TRUE).
#   - For every person that does NOT already have a membership on the host
#     platform, insert a new active membership with the best available role:
#       1. 'platform_steward'  (the new canonical name)
#       2. 'platform_manager'  (legacy name kept during the identifier transition)
#     The role selection uses whichever exists; 'platform_manager' is the safe
#     fallback for instances that have not yet run the RBAC identifier rename.
#
# This migration is intentionally idempotent — re-running it against a database
# that already has the memberships is a no-op because of the LEFT JOIN / WHERE
# NULL pattern.
class BackfillHostPlatformMemberships < ActiveRecord::Migration[7.2]
  def up
    result = execute(<<~SQL)
      SELECT p.id                              AS host_platform_id,
             COALESCE(r_steward.id, r_mgr.id) AS role_id
      FROM   better_together_platforms p
      LEFT JOIN better_together_roles r_steward
             ON r_steward.identifier = 'platform_steward'
      LEFT JOIN better_together_roles r_mgr
             ON r_mgr.identifier    = 'platform_manager'
      WHERE  p.host = TRUE
      LIMIT  1
    SQL

    row = result.first
    return unless row
    return unless row['role_id']

    host_platform_id = row['host_platform_id']
    role_id          = row['role_id']

    execute <<~SQL
      INSERT INTO better_together_person_platform_memberships
             (id, member_id, joinable_id, role_id, status, lock_version, created_at, updated_at)
      SELECT gen_random_uuid(),
             p.id,
             '#{host_platform_id}',
             '#{role_id}',
             'active',
             0,
             NOW(),
             NOW()
      FROM   better_together_people p
      WHERE  NOT EXISTS (
               SELECT 1
               FROM   better_together_person_platform_memberships m
               WHERE  m.member_id   = p.id
                 AND  m.joinable_id = '#{host_platform_id}'
             )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
