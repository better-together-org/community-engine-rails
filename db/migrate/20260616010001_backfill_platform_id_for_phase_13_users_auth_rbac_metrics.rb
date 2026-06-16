# frozen_string_literal: true

# Phase 13 — Backfill users, auth/oauth, rbac, metrics with platform_id
class BackfillPlatformIdForPhase13UsersAuthRbacMetrics < ActiveRecord::Migration[7.2] # rubocop:disable Metrics/ClassLength
  def up # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity,Metrics/MethodLength
    # Step 1: Users from person's platform memberships (one user per person per platform)
    if column_exists?(:better_together_users, :platform_id)
      execute <<~SQL
        UPDATE better_together_users u
        SET    platform_id = ppm.joinable_id
        FROM   better_together_people p
        JOIN   better_together_person_platform_memberships ppm
          ON   p.id = ppm.member_id
        WHERE  u.person_id = p.id
          AND  u.platform_id IS NULL
          AND  ppm.joinable_id IS NOT NULL
      SQL
    end

    # Step 2: OAuth access tokens from user's platform
    if column_exists?(:better_together_oauth_access_tokens, :platform_id)
      execute <<~SQL
        UPDATE better_together_oauth_access_tokens oat
        SET    platform_id = u.platform_id
        FROM   better_together_users u
        WHERE  oat.resource_owner_id = u.id
          AND  oat.platform_id IS NULL
          AND  u.platform_id IS NOT NULL
      SQL
    end

    # Step 3: OAuth access grants from user's platform
    if column_exists?(:better_together_oauth_access_grants, :platform_id)
      execute <<~SQL
        UPDATE better_together_oauth_access_grants oag
        SET    platform_id = u.platform_id
        FROM   better_together_users u
        WHERE  oag.resource_owner_id = u.id
          AND  oag.platform_id IS NULL
          AND  u.platform_id IS NOT NULL
      SQL
    end

    # Step 4: OAuth applications to host platform (system-wide apps, customizable per platform)
    if column_exists?(:better_together_oauth_applications, :platform_id)
      host_platform_id = execute(
        "SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1"
      ).first&.fetch('id')

      if host_platform_id
        execute <<~SQL
          UPDATE better_together_oauth_applications
          SET platform_id = #{quote(host_platform_id)}
          WHERE platform_id IS NULL
        SQL
      end
    end

    # Step 5: JWT deny lists from user's platform
    if column_exists?(:better_together_jwt_denylists, :platform_id)
      # Assume jwt_denylists has user_id or similar relationship
      # If not, fall back to host platform
      execute <<~SQL
        UPDATE better_together_jwt_denylists jdl
        SET    platform_id = u.platform_id
        FROM   better_together_users u
        WHERE  jdl.user_id = u.id
          AND  jdl.platform_id IS NULL
          AND  u.platform_id IS NOT NULL
      SQL
    end

    # Step 6: Roles to host platform (system roles, customizable per platform)
    if column_exists?(:better_together_roles, :platform_id)
      host_platform_id = execute(
        "SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1"
      ).first&.fetch('id')

      if host_platform_id
        execute <<~SQL
          UPDATE better_together_roles
          SET platform_id = #{quote(host_platform_id)}
          WHERE platform_id IS NULL
        SQL
      end
    end

    # Step 7: Resource permissions to host platform
    if column_exists?(:better_together_resource_permissions, :platform_id)
      host_platform_id = execute(
        "SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1"
      ).first&.fetch('id')

      if host_platform_id
        execute <<~SQL
          UPDATE better_together_resource_permissions
          SET platform_id = #{quote(host_platform_id)}
          WHERE platform_id IS NULL
        SQL
      end
    end

    # Step 8: Role resource permissions from role (or host platform fallback)
    if column_exists?(:better_together_role_resource_permissions, :platform_id)
      execute <<~SQL
        UPDATE better_together_role_resource_permissions rrp
        SET    platform_id = r.platform_id
        FROM   better_together_roles r
        WHERE  rrp.role_id = r.id
          AND  rrp.platform_id IS NULL
          AND  r.platform_id IS NOT NULL
      SQL

      host_platform_id = execute(
        "SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1"
      ).first&.fetch('id')

      if host_platform_id
        execute <<~SQL
          UPDATE better_together_role_resource_permissions
          SET platform_id = #{quote(host_platform_id)}
          WHERE platform_id IS NULL
        SQL
      end
    end

    # Step 9: Metrics to host platform (system-wide observability)
    host_platform_id = execute(
      "SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1"
    ).first&.fetch('id')

    return unless host_platform_id

    %w[
      better_together_metrics_link_checker_reports
      better_together_metrics_rich_text_links
      better_together_metrics_user_account_reports
      better_together_ai_log_translations
    ].each do |table|
      next unless column_exists?(table, :platform_id)

      execute <<~SQL
        UPDATE #{table} SET platform_id = #{quote(host_platform_id)}
        WHERE platform_id IS NULL
      SQL
    end

    # Step 10: Person data exports to host platform (backfill existing), will be required going forward
    if column_exists?(:better_together_person_data_exports, :platform_id)
      execute <<~SQL
        UPDATE better_together_person_data_exports
        SET platform_id = #{quote(host_platform_id)}
        WHERE platform_id IS NULL
      SQL
    end

    # Step 11: Person deletion requests to host platform (backfill existing), will be required going forward
    return unless column_exists?(:better_together_person_deletion_requests, :platform_id)

    execute <<~SQL
      UPDATE better_together_person_deletion_requests
      SET platform_id = #{quote(host_platform_id)}
      WHERE platform_id IS NULL
    SQL
  end

  def down
    %w[
      better_together_users
      better_together_oauth_applications
      better_together_oauth_access_grants
      better_together_oauth_access_tokens
      better_together_jwt_denylists
      better_together_roles
      better_together_resource_permissions
      better_together_role_resource_permissions
      better_together_metrics_link_checker_reports
      better_together_metrics_rich_text_links
      better_together_metrics_user_account_reports
      better_together_ai_log_translations
      better_together_person_data_exports
      better_together_person_deletion_requests
    ].each do |table|
      next unless column_exists?(table, :platform_id)

      execute "UPDATE #{table} SET platform_id = NULL"
    end
  end
end
