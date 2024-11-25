class CreateBetterTogetherMetricsRichTextLinks < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :rich_text_links, prefix: :better_together_metrics do |t|
      t.bt_references :link, foreign_key: { to_table: :better_together_content_links }
      # Data re: the RichText and record
      t.bt_references :rich_text, foreign_key: { to_table: :action_text_rich_texts }
      t.bt_references :rich_text_record, polymorphic: true, index: { name: 'by_rich_text_link_record' }
      t.bt_position # index in the RichText links array
      t.bt_locale # locale of the RichText content

      t.index [:rich_text_id, :position, :locale], unique: true
    end
  end
end
