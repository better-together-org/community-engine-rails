# frozen_string_literal: true

# Creates the PlatformInvitations database table
class CreateBetterTogetherPlatformInvitations < ActiveRecord::Migration[7.1]
  def change # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
    create_bt_table :platform_invitations, id: :uuid do |t| # rubocop:todo Metrics/BlockLength
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

      t.string  :locale,
                limit: 5,
                null: false,
                index: {
                  name: 'platform_invitations_by_locale'
                },
                default: I18n.default_locale

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
      t.datetime :accepted_at
      t.datetime :declined_at
    end

    add_index :better_together_platform_invitations, %i[invitee_email invitable_id], unique: true
    add_index :better_together_platform_invitations, %i[invitable_id status],
              name: "index_platform_invitations_on_invitable_id_and_status"
    add_index :better_together_platform_invitations, :invitee_email, where: "status = 'pending'",
                                                                     name: "index_pending_invitations_on_invitee_email"
  end
end
