# frozen_string_literal: true

# Creates pages table
class CreateBetterTogetherPages < ActiveRecord::Migration[7.0]
  def change # rubocop:todo Metrics/MethodLength
    create_bt_table :pages do |t|
      t.bt_identifier
      t.bt_protected
      t.bt_privacy
      t.bt_slug

      t.text :meta_description
      t.string :keywords
      t.boolean :published,
                index: {
                  name: 'by_page_publication_status'
                }
      t.datetime :published_at,
                 index: {
                   name: 'by_page_publication_date'
                 }

      t.string :layout
      t.string :template
    end
  end
end
