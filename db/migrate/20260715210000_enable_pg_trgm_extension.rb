# frozen_string_literal: true

# Enables pg_trgm for trigram-similarity name matching (used as a State resolution
# fallback in HierarchyResolutionJob when no boundary polygon is available). Also adds a
# GIN trigram index on the shared mobility_string_translations table's `value` column —
# this benefits any future similarity search against a Mobility-translated attribute, not
# just State#name, since every translated attribute in the app stores its value there.
class EnablePgTrgmExtension < ActiveRecord::Migration[7.1]
  def change
    enable_extension 'pg_trgm' unless extension_enabled?('pg_trgm')

    return if index_exists?(:mobility_string_translations, :value,
                            name: 'index_mobility_string_translations_on_value_trgm')

    add_index :mobility_string_translations, :value,
              using: :gin,
              opclass: :gin_trgm_ops,
              name: 'index_mobility_string_translations_on_value_trgm'
  end
end
