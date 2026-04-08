# frozen_string_literal: true

class InstallActionMailboxAndInboundEmailScreening < ActiveRecord::Migration[7.2]
  def up
    create_action_mailbox_inbound_emails_table
    create_better_together_inbound_email_messages_table
    ensure_better_together_inbound_email_message_columns
    ensure_better_together_inbound_email_message_indexes
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Inbound mail screening installation is not reversible automatically.'
  end

  private

  def create_action_mailbox_inbound_emails_table
    return if table_exists?(:action_mailbox_inbound_emails)

    create_table :action_mailbox_inbound_emails, id: :uuid do |t|
      t.integer :status, default: 0, null: false
      t.string :message_id, null: false
      t.string :message_checksum, null: false
      t.timestamps
    end

    add_index :action_mailbox_inbound_emails,
              %i[message_id message_checksum],
              unique: true,
              name: 'index_action_mailbox_inbound_emails_uniqueness'
  end

  def create_better_together_inbound_email_messages_table
    return if table_exists?(:better_together_inbound_email_messages)

    create_table :better_together_inbound_email_messages, id: :uuid do |t|
      t.references :inbound_email, null: false, type: :uuid, foreign_key: { to_table: :action_mailbox_inbound_emails }
      t.references :platform, type: :uuid, foreign_key: { to_table: :better_together_platforms }
      t.string :route_kind, null: false
      t.string :status, null: false, default: 'received'
      t.references :target, polymorphic: true, type: :uuid
      t.references :routed_record, polymorphic: true, type: :uuid
      t.string :message_id, null: false
      t.string :sender_email, null: false
      t.string :sender_name
      t.string :recipient_address, null: false
      t.string :recipient_local_part, null: false
      t.string :recipient_domain, null: false
      t.text :subject
      t.text :body_plain
      t.string :screening_state, null: false, default: 'pending'
      t.string :screening_verdict
      t.text :content_screening_summary
      t.text :content_security_records_json
      t.timestamps
    end
  end

  def ensure_better_together_inbound_email_message_columns
    return unless table_exists?(:better_together_inbound_email_messages)

    ensure_platform_reference
    ensure_screening_columns
    ensure_inbound_email_foreign_key
  end

  def ensure_better_together_inbound_email_message_indexes
    return unless table_exists?(:better_together_inbound_email_messages)

    add_index :better_together_inbound_email_messages, :message_id unless index_exists?(:better_together_inbound_email_messages, :message_id)
    add_index :better_together_inbound_email_messages, %i[route_kind status] unless
      index_exists?(:better_together_inbound_email_messages, %i[route_kind status])
    add_index :better_together_inbound_email_messages, :screening_state unless
      index_exists?(:better_together_inbound_email_messages, :screening_state)
    add_index :better_together_inbound_email_messages, :screening_verdict unless
      index_exists?(:better_together_inbound_email_messages, :screening_verdict)
  end

  def ensure_platform_reference
    return if column_exists?(:better_together_inbound_email_messages, :platform_id)

    add_reference :better_together_inbound_email_messages,
                  :platform,
                  type: :uuid,
                  foreign_key: { to_table: :better_together_platforms }
  end

  def ensure_screening_columns
    add_screening_state_column
    add_screening_verdict_column
    add_content_screening_summary_column
    add_content_security_records_column
  end

  def add_screening_state_column
    return if column_exists?(:better_together_inbound_email_messages, :screening_state)

    add_column :better_together_inbound_email_messages, :screening_state, :string, null: false, default: 'pending'
  end

  def add_screening_verdict_column
    return if column_exists?(:better_together_inbound_email_messages, :screening_verdict)

    add_column :better_together_inbound_email_messages, :screening_verdict, :string
  end

  def add_content_screening_summary_column
    return if column_exists?(:better_together_inbound_email_messages, :content_screening_summary)

    add_column :better_together_inbound_email_messages, :content_screening_summary, :text
  end

  def add_content_security_records_column
    return if column_exists?(:better_together_inbound_email_messages, :content_security_records_json)

    add_column :better_together_inbound_email_messages, :content_security_records_json, :text
  end

  def ensure_inbound_email_foreign_key
    return if foreign_key_exists?(:better_together_inbound_email_messages, :action_mailbox_inbound_emails, column: :inbound_email_id)

    add_foreign_key :better_together_inbound_email_messages, :action_mailbox_inbound_emails, column: :inbound_email_id
  end
end
