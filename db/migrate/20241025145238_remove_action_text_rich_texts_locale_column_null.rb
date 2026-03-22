# frozen_string_literal: true

# Allows rich texts to have a null locale in the context of encrypted message contents
class RemoveActionTextRichTextsLocaleColumnNull < ActiveRecord::Migration[7.1]
  def change
    change_column_null :action_text_rich_texts, :locale, true
  end
end
