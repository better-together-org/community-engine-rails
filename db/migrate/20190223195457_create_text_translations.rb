# frozen_string_literal: true

# Creates text translations table
class CreateTextTranslations < ActiveRecord::Migration[7.0]
  def change # rubocop:todo Metrics/MethodLength
    create_table :mobility_text_translations do |t|
      t.string :locale, null: false
      t.string :key,    null: false
      t.text :value
      t.bt_references :translatable, polymorphic: true, index: false
      t.timestamps null: false
    end
    add_index :mobility_text_translations,
              %i[translatable_id translatable_type locale key],
              unique: true,
              name: :index_mobility_text_translations_on_keys
    add_index :mobility_text_translations, %i[translatable_id translatable_type key],
              name: :index_mobility_text_translations_on_translatable_attribute
  end
end
