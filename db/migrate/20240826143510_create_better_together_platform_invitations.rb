class CreateBetterTogetherPlatformInvitations < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :platform_invitations, id: :uuid do |t|
      
      # Reference to the better_together_roles table for the role
      t.bt_references :community_role,
                      null: false,
                      index: { name: 'platform_invitations_by_community_role' },
                      target_table: :better_together_roles
      
      t.string :invitee_email,
               null: false,
               index: {
                 name: 'platform_invitations_by_invitee_email'
               }

      t.bt_references :invitable,
                      null: false,
                      target_table: :better_together_platforms,
                      index: {
                        name: 'platform_invitations_by_invitable'
                      }

      t.bt_references :invitee,
                      target_table: :better_together_people,
                      index: {
                        name: 'platform_invitations_by_invitee'
                      }

      t.bt_references :inviter,
                      null: false,
                      target_table: :better_together_people,
                      index: {
                        name: 'platform_invitations_by_inviter'
                      }
      
      # Reference to the better_together_roles table for the role
      t.bt_references :platform_role,
                      null: false,
                      index: { name: 'platform_invitations_by_platform_role' },
                      target_table: :better_together_roles

      t.string  :status,
                limit: 20,
                null: false,
                index: {
                  name: 'platform_invitations_by_status'
                }
    
      t.string  :token,
                limit: 24,
                null: false,
                index: {
                  name: 'platform_invitations_by_token',
                  unique: true
                }

      t.datetime :valid_from,
                 null: false,
                 index: {
                   name: 'platform_invitations_by_valid_from'
                 }
      t.datetime :valid_until,
                 index: {
                   name: 'platform_invitations_by_valid_until'
                 }
      t.datetime :last_sent
    end

    add_index :better_together_platform_invitations, %i[invitee_email invitable_id], unique: true
  end
end
