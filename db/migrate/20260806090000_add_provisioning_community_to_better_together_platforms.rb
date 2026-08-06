# frozen_string_literal: true

# Records which Community (if any) kicked off a Platform's new_platform_setup
# wizard run via the billing-gated entitlement flow, so a billing-provisioned
# platform can be traced back to the community that paid for it. Null for
# platforms provisioned through the staff-facing NewPlatformSetupController
# entry point directly (no paying community involved).
class AddProvisioningCommunityToBetterTogetherPlatforms < ActiveRecord::Migration[7.2]
  def change
    return unless table_exists?(:better_together_platforms)

    unless column_exists?(:better_together_platforms, :provisioning_community_id)
      add_reference :better_together_platforms, :provisioning_community,
                    type: :uuid, null: true, index: false
    end

    unless foreign_key_exists?(:better_together_platforms, :better_together_communities,
                               column: :provisioning_community_id)
      add_foreign_key :better_together_platforms, :better_together_communities,
                      column: :provisioning_community_id, on_delete: :nullify
    end

    unless index_exists?(:better_together_platforms, :provisioning_community_id,
                         name: 'idx_bt_platforms_provisioning_community')
      add_index :better_together_platforms, :provisioning_community_id,
                name: 'idx_bt_platforms_provisioning_community'
    end
  end
end
