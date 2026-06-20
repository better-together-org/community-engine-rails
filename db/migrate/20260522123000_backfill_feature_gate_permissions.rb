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
      permission.save!
    end
  end

  def assign_permission_to_roles!(permission_identifier, role_identifiers)
    permission = BetterTogether::ResourcePermission.find_by!(identifier: permission_identifier)

    BetterTogether::Role.where(identifier: role_identifiers).find_each do |role|
      BetterTogether::RoleResourcePermission.find_or_create_by!(role:, resource_permission: permission)
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
