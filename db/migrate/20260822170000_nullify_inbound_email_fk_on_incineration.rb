# frozen_string_literal: true

# Rails' default ActionMailbox::IncinerationJob (~30 days) destroys
# action_mailbox_inbound_emails rows. The original FK from
# better_together_inbound_email_messages had no on_delete option (default
# RESTRICT), so incineration of an aged-out email raised
# ActiveRecord::InvalidForeignKey once the first inbound emails aged past the
# incineration window. Nullify instead: the CE-side message record is the
# durable record of the inbound email; the raw ActionMailbox row is disposable.
class NullifyInboundEmailFkOnIncineration < ActiveRecord::Migration[7.2]
  def change
    return unless table_exists?(:better_together_inbound_email_messages)

    change_column_null :better_together_inbound_email_messages, :inbound_email_id, true

    if foreign_key_exists?(:better_together_inbound_email_messages, :action_mailbox_inbound_emails,
                           column: :inbound_email_id)
      remove_foreign_key :better_together_inbound_email_messages, :action_mailbox_inbound_emails,
                         column: :inbound_email_id
    end

    add_foreign_key :better_together_inbound_email_messages, :action_mailbox_inbound_emails,
                    column: :inbound_email_id, on_delete: :nullify
  end
end
