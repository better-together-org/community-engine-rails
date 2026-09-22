# frozen_string_literal: true

# Phase 13 — Users, Auth/OAuth, RBAC, Metrics, Logs, Exports/Deletions
class AddPlatformIdToPhase13UsersAuthRbacMetrics < ActiveRecord::Migration[7.2] # rubocop:disable Metrics/ClassLength
  def change # rubocop:disable Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
    # Users: one user per person per platform (from person's platform memberships)
    unless column_exists?(:better_together_users, :platform_id)
      add_reference :better_together_users, :platform,
                    type: :uuid, null: true,
                    foreign_key: { to_table: :better_together_platforms },
                    index: true
    end

    # OAuth: applications, access grants, access tokens (platform-scoped auth)
    %w[
      better_together_oauth_applications
      better_together_oauth_access_grants
      better_together_oauth_access_tokens
    ].each do |table|
      next if column_exists?(table, :platform_id)

      add_reference table, :platform,
                    type: :uuid, null: true,
                    foreign_key: { to_table: :better_together_platforms },
                    index: true
    end

    # JWT deny list (platform-scoped token revocation)
    unless column_exists?(:better_together_jwt_denylists, :platform_id)
      add_reference :better_together_jwt_denylists, :platform,
                    type: :uuid, null: true,
                    foreign_key: { to_table: :better_together_platforms },
                    index: true
    end

    # RBAC: roles, permissions, mappings (platform-scoped role definitions)
    %w[
      better_together_roles
      better_together_resource_permissions
      better_together_role_resource_permissions
    ].each do |table|
      next if column_exists?(table, :platform_id)

      add_reference table, :platform,
                    type: :uuid, null: true,
                    foreign_key: { to_table: :better_together_platforms },
                    index: true
    end

    # Metrics & Logs (platform-scoped observability)
    %w[
      better_together_metrics_link_checker_reports
      better_together_metrics_rich_text_links
      better_together_metrics_user_account_reports
      better_together_ai_log_translations
    ].each do |table|
      next if column_exists?(table, :platform_id)

      add_reference table, :platform,
                    type: :uuid, null: true,
                    foreign_key: { to_table: :better_together_platforms },
                    index: true
    end

    # Person data: exports and deletions become platform-scoped
    # Make person_data_exports.platform_id NOT NULL (already exists, nullable)
    if column_exists?(:better_together_person_data_exports, :platform_id)
      change_column_null :better_together_person_data_exports, :platform_id, false
    else
      add_reference :better_together_person_data_exports, :platform,
                    type: :uuid, null: false,
                    foreign_key: { to_table: :better_together_platforms },
                    index: true
    end

    # Make person_deletion_requests.platform_id NOT NULL (already exists, nullable)
    if column_exists?(:better_together_person_deletion_requests, :platform_id)
      change_column_null :better_together_person_deletion_requests, :platform_id, false
    else
      add_reference :better_together_person_deletion_requests, :platform,
                    type: :uuid, null: false,
                    foreign_key: { to_table: :better_together_platforms },
                    index: true
    end
  end
end
