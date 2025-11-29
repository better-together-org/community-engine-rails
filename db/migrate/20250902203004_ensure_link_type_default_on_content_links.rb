# frozen_string_literal: true

# Migration to ensure `link_type` on better_together_content_links has a sensible
# default (`'website'`) and is non-nullable to satisfy callers that expect a
# present link_type value.
class EnsureLinkTypeDefaultOnContentLinks < ActiveRecord::Migration[7.1]
  def up
    table = :better_together_content_links
    if column_exists?(table, :link_type)
      change_column_default table, :link_type, 'website'
      # Set existing nulls to default before enforcing NOT NULL
      execute <<-SQL.squish
        UPDATE #{table} SET link_type = 'website' WHERE link_type IS NULL
      SQL
      change_column_null table, :link_type, false
    else
      add_column table, :link_type, :string, null: false, default: 'website'
    end
  end

  def down
    table = :better_together_content_links
    return unless column_exists?(table, :link_type)

    change_column_null table, :link_type, true
    change_column_default table, :link_type, nil
  end
end
