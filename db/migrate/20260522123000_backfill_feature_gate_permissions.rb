# frozen_string_literal: true

class BackfillFeatureGatePermissions < ActiveRecord::Migration[7.2]
  FEATURE_PERMISSION_ATTRIBUTES = [
    {
      action: 'view',
      target: 'beta_features',
      resource_type: 'BetterTogether::Platform',
      identifier: 'access_beta_features',
      protected: true,
      position: 26
    },
    {
      action: 'view',
      target: 'alpha_features',
      resource_type: 'BetterTogether::Platform',
      identifier: 'access_alpha_features',
      protected: true,
      position: 27
    }
  ].freeze

  BETA_ROLE_IDENTIFIERS = %w[
    platform_steward
    platform_manager
    platform_infrastructure_architect
    platform_tech_support
    platform_developer
    platform_quality_assurance_lead
    platform_accessibility_officer
  ].freeze

  ALPHA_ROLE_IDENTIFIERS = %w[
    platform_steward
    platform_manager
    platform_infrastructure_architect
    platform_tech_support
    platform_developer
    platform_quality_assurance_lead
  ].freeze

  def up
    ensure_permissions!
    assign_permission_to_roles!('access_beta_features', BETA_ROLE_IDENTIFIERS)
    assign_permission_to_roles!('access_alpha_features', ALPHA_ROLE_IDENTIFIERS)
  end

  def down
    remove_permission_from_roles!('access_beta_features', BETA_ROLE_IDENTIFIERS)
    remove_permission_from_roles!('access_alpha_features', ALPHA_ROLE_IDENTIFIERS)
  end

  private

  def ensure_permissions!
    FEATURE_PERMISSION_ATTRIBUTES.each do |attributes|
      permission = BetterTogether::ResourcePermission.find_or_initialize_by(identifier: attributes.fetch(:identifier))
      permission.assign_attributes(attributes)
      # validate: false bypasses ResourcePermission's belongs_to :platform
      # requirement, added to the live model long after this migration was
      # written. platform_id doesn't exist on this table yet on a host that
      # hasn't run add_platform_id_to_phase13_users_auth_rbac_metrics, so the
      # association can never resolve here regardless of Platform data. The
      # other attributes are static constants above, and the DB still
      # enforces the [resource_type, position] unique index either way.
      permission.save!(validate: false)
    end
  end

  def assign_permission_to_roles!(permission_identifier, role_identifiers)
    permission = BetterTogether::ResourcePermission.find_by!(identifier: permission_identifier)

    BetterTogether::Role.where(identifier: role_identifiers).find_each do |role|
      link = BetterTogether::RoleResourcePermission.find_or_initialize_by(role:, resource_permission: permission)
      link.save!(validate: false) if link.new_record?
    end
  end

  def remove_permission_from_roles!(permission_identifier, role_identifiers)
    permission = BetterTogether::ResourcePermission.find_by(identifier: permission_identifier)
    return unless permission

    BetterTogether::RoleResourcePermission.where(
      role_id: BetterTogether::Role.where(identifier: role_identifiers).select(:id),
      resource_permission_id: permission.id
    ).delete_all
  end
end
