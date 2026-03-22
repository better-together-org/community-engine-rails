# frozen_string_literal: true

class CreateBetterTogetherMetricsSearchQueries < ActiveRecord::Migration[7.1] # rubocop:todo Style/Documentation
  def change
    create_bt_table :search_queries, prefix: :better_together_metrics do |t|
      t.bt_locale
      t.string :query, null: false
      t.integer :results_count, null: false
      t.datetime :searched_at, null: false
    end
  end
end
