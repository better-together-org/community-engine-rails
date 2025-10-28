class AddTranslationPerformanceIndices < ActiveRecord::Migration[8.0]
  def change
    # Optimize string translation queries
    add_index :mobility_string_translations, %i[translatable_type locale key],
              name: 'index_string_translations_on_type_locale_key'
    add_index :mobility_string_translations, %i[translatable_type translatable_id],
              name: 'index_string_translations_on_type_id'

    # Optimize text translation queries
    add_index :mobility_text_translations, %i[translatable_type locale key],
              name: 'index_text_translations_on_type_locale_key'
    add_index :mobility_text_translations, %i[translatable_type translatable_id],
              name: 'index_text_translations_on_type_id'

    # Optimize ActionText queries
    add_index :action_text_rich_texts, %i[record_type locale name],
              name: 'index_rich_texts_on_type_locale_name'
    add_index :action_text_rich_texts, %i[record_type record_id],
              name: 'index_rich_texts_on_type_id'

    # Optimize ActiveStorage queries for file translations
    add_index :active_storage_attachments, %i[record_type record_id name],
              name: 'index_attachments_on_type_id_name'
  end
end
