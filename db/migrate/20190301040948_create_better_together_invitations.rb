# frozen_string_literal: true

# Creates invitations table
class CreateBetterTogetherInvitations < ActiveRecord::Migration[7.0]
  def change # rubocop:todo Metrics/MethodLength, Metrics/AbcSize
    create_bt_table :invitations do |t| # rubocop:todo Metrics/BlockLength
      t.string "type", default: "BetterTogether::Invitation", null: false
      t.string :status,
               limit: 20,
               null: false,
               index: {
                 name: 'by_status'
               }
      t.datetime :valid_from,
                 null: false,
                 index: {
                   name: 'by_valid_from'
                 }
      t.datetime :valid_until,
                 index: {
                   name: 'by_valid_until'
                 }
      t.datetime :last_sent
      t.datetime :accepted_at

      t.bt_locale('better_together_invitations')

      t.string :token,
               limit: 24,
               null: false,
               index: {
                 name: 'invitations_by_token',
                 unique: true
               }

      t.bt_references :invitable,
                      null: false,
                      polymorphic: true,
                      index: {
                        name: 'by_invitable'
                      }
      t.bt_references  :inviter,
                       null: false,
                       polymorphic: true,
                       index: {
                         name: 'by_inviter'
                       }
      t.bt_references  :invitee,
                       null: false,
                       polymorphic: true,
                       index: {
                         name: 'by_invitee'
                       }
      t.string :invitee_email,
               null: false,
               index: {
                 name: 'invitations_by_invitee_email'
               }

      t.bt_references :role,
                      index: {
                        name: 'by_role'
                      }
    end

    add_index :better_together_invitations, %i[invitee_email invitable_id], unique: true,
                                                                            # rubocop:todo Layout/LineLength
                                                                            name: "invitations_on_invitee_email_and_invitable_id"
    # rubocop:enable Layout/LineLength
    add_index :better_together_invitations, %i[invitable_id status],
              name: "invitations_on_invitable_id_and_status"
    add_index :better_together_invitations, :invitee_email, where: "status = 'pending'",
                                                            name: "pending_invites_on_invitee_email"
  end
end
