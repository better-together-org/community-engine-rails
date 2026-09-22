# frozen_string_literal: true

class AllowEmailOnlyBetterTogetherInvitations < ActiveRecord::Migration[7.2]
  TABLE = :better_together_invitations

  def up
    change_column_null TABLE, :invitee_type, true if column_exists?(TABLE, :invitee_type)
    change_column_null TABLE, :invitee_id, true if column_exists?(TABLE, :invitee_id)
  end

  def down
    raise_irreversible_email_only_invites! if email_only_invites_exist?

    change_column_null TABLE, :invitee_type, false if column_exists?(TABLE, :invitee_type)
    change_column_null TABLE, :invitee_id, false if column_exists?(TABLE, :invitee_id)
  end

  private

  def email_only_invites_exist?
    select_value(<<~SQL.squish).to_i.positive?
      SELECT COUNT(*)
      FROM #{TABLE}
      WHERE invitee_type IS NULL OR invitee_id IS NULL
    SQL
  end

  def raise_irreversible_email_only_invites!
    raise ActiveRecord::IrreversibleMigration,
          'Cannot restore NOT NULL invitee columns while email-only invitations exist'
  end
end
