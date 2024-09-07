class CreateBetterTogetherContentBlocks < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :blocks, prefix: 'better_together_content'  do |t|
      t.string :type, null: false

      t.bt_identifier(null: true)

      t.jsonb :accessibility_attributes, null: false, default: {}
      t.jsonb :content_settings, null: false, default: {}
      t.jsonb :css_settings, null: false, default: {}
      t.jsonb :data_attributes, null: false, default: {}
      t.jsonb :html_attributes, null: false, default: {}
      t.jsonb :layout_settings, null: false, default: {}
      t.jsonb :media_settings, null: false, default: {}
    end
  end
end
