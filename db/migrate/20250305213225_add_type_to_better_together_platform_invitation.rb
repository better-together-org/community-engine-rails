class AddTypeToBetterTogetherPlatformInvitation < ActiveRecord::Migration[7.1]
  def change
    add_column :better_together_platform_invitations, :type, :string, null: false, default: 'BetterTogether::PlatformInvitation'
    add_index :better_together_platform_invitations, :type, name: 'platform_invitations_by_type'
  end
end
