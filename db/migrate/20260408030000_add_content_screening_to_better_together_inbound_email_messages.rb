# frozen_string_literal: true

class AddContentScreeningToBetterTogetherInboundEmailMessages < ActiveRecord::Migration[7.2]
  def change
    return unless table_exists?(:better_together_inbound_email_messages)

    {
      screening_state: [:string, { null: false, default: 'pending' }],
      screening_verdict: [:string, {}],
      content_screening_summary: [:text, {}],
      content_security_records_json: [:text, {}]
    }.each do |column_name, (type, options)|
      next if column_exists?(:better_together_inbound_email_messages, column_name)

      add_column :better_together_inbound_email_messages, column_name, type, **options
    end

    %i[screening_state screening_verdict].each do |column_name|
      next if index_exists?(:better_together_inbound_email_messages, column_name)

      add_index :better_together_inbound_email_messages, column_name
    end
  end
end
