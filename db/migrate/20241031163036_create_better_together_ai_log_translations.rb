# frozen_string_literal: true

class CreateBetterTogetherAiLogTranslations < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :ai_log_translations do |t|
      t.text :request, null: false
      t.text :response
      t.string :model, null: false, index: true
      t.integer :prompt_tokens, default: 0, null: false
      t.integer :completion_tokens, default: 0, null: false
      t.integer :tokens_used, default: 0, null: false
      t.decimal :estimated_cost, precision: 10, scale: 5, default: 0.0, null: false
      t.datetime :start_time
      t.datetime :end_time
      t.string :status, null: false, default: 'pending', index: true

      t.bt_references :initiator, target_table: :better_together_people, null: true

      t.string :source_locale, null: false, index: true
      t.string :target_locale, null: false, index: true
    end
  end
end
