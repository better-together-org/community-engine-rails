# frozen_string_literal: true

# Phase 3 — Category and Categorization isolation.
# Categories (event, joatu, page) were global; now per-platform.
# Categorizations join table also gets platform_id for efficient scoped queries.
class AddPlatformIdToCategories < ActiveRecord::Migration[7.2]
  def change
    add_reference :better_together_categories, :platform,
                  type: :uuid,
                  null: true,
                  foreign_key: { to_table: :better_together_platforms },
                  index: true

    add_reference :better_together_categorizations, :platform,
                  type: :uuid,
                  null: true,
                  foreign_key: { to_table: :better_together_platforms },
                  index: true
  end
end
