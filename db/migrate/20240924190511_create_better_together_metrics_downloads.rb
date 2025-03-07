# frozen_string_literal: true

class CreateBetterTogetherMetricsDownloads < ActiveRecord::Migration[7.1] # rubocop:todo Style/Documentation
  def change
    create_bt_table :downloads, prefix: :better_together_metrics do |t|
      t.bt_locale
      t.bt_references :downloadable, polymorphic: true, index: true
      t.string :file_name, null: false
      t.string :file_type, null: false
      t.bigint :file_size, null: false
      t.datetime :downloaded_at, null: false
    end
  end
end
