# frozen_string_literal: true

# Adds display settings to pages.
class AddDisplaySettingsToPages < ActiveRecord::Migration[7.2]
  def up
    add_column :better_together_pages, :display_settings, :jsonb, default: {}, null: false

    # Backfill existing pages to hide title by default
    # New pages will use the model default of true
    BetterTogether::Page.reset_column_information
    BetterTogether::Page.where(display_settings: {}).update_all(display_settings: { show_title: false })
  end

  def down
    remove_column :better_together_pages, :display_settings
  end
end
