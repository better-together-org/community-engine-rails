# frozen_string_literal: true

# Creates reports for flagged content or users
class CreateBetterTogetherReports < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :reports do |t|
      t.references :reporter, null: false, type: :uuid, foreign_key: { to_table: :better_together_people }
      t.uuid :reportable_id, null: false
      t.string :reportable_type, null: false
      t.text :reason
    end
  end
end
