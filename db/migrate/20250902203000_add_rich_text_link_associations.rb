# Migration to add association columns to better_together_metrics_rich_text_links
class AddRichTextLinkAssociations < ActiveRecord::Migration[7.1]
  def change
    add_column :better_together_metrics_rich_text_links, :link_id, :uuid
    add_column :better_together_metrics_rich_text_links, :rich_text_record_type, :string
    add_column :better_together_metrics_rich_text_links, :rich_text_record_id, :uuid

    add_index :better_together_metrics_rich_text_links, :link_id,
              name: 'bt_metrics_rich_text_links_on_link_id'
    add_index :better_together_metrics_rich_text_links, %i[rich_text_record_type rich_text_record_id],
              name: 'bt_metrics_rich_text_links_on_rich_text_record'
  end
end
