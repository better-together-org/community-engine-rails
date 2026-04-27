# frozen_string_literal: true

class AddTranslationCoverageLookupIndexes < ActiveRecord::Migration[7.2]
  STRING_INDEX = 'index_mobility_string_translations_on_type_locale_key'
  TEXT_INDEX = 'index_mobility_text_translations_on_type_locale_key'

  def up
    unless index_exists?(:mobility_string_translations, %i[translatable_type locale key], name: STRING_INDEX)
      add_index :mobility_string_translations, %i[translatable_type locale key], name: STRING_INDEX
    end

    return if index_exists?(:mobility_text_translations, %i[translatable_type locale key], name: TEXT_INDEX)

    add_index :mobility_text_translations, %i[translatable_type locale key], name: TEXT_INDEX
  end

  def down
    remove_index :mobility_string_translations, name: STRING_INDEX if index_exists?(:mobility_string_translations,
                                                                                    %i[translatable_type locale key],
                                                                                    name: STRING_INDEX)
    remove_index :mobility_text_translations, name: TEXT_INDEX if index_exists?(:mobility_text_translations,
                                                                                %i[translatable_type locale key],
                                                                                name: TEXT_INDEX)
  end
end
