# frozen_string_literal: true

# Creates pages table
class CreateBetterTogetherPages < ActiveRecord::Migration[7.0]
  def change # rubocop:todo Metrics/MethodLength
    create_bt_table :pages do |t|
      t.bt_identifier
      t.bt_protected
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

      t.string :privacy,
               index: {
                 name: 'by_page_privacy'
               },
               null: false,
               default: 'public'
      t.string :layout
      t.string :template
      t.string :language, default: 'en'
      # t.text :custom_fields # can be implemented as JSON or serialized text
      # t.integer :parent_id # for hierarchical structuring
    end
  end
end
