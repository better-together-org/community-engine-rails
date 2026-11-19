# frozen_string_literal: true

# Replaces the platforms.external boolean with a locality string enum ('local' or 'remote').
#
# external = true  -> 'remote' (not served by this instance: OAuth providers, federated peers)
# external = false -> 'local'
#
# Locality is its own field because type no longer implies it: operator and hosted platforms can be remote too.
# Guarded for partial-schema reruns. The external column and its index are dropped once locality is filled;
# rollback restores both from locality.
class ReplacePlatformExternalWithLocality < ActiveRecord::Migration[7.2]
  TABLE = :better_together_platforms
  LOCALITY_INDEX = 'index_better_together_platforms_on_locality'
  EXTERNAL_INDEX = 'index_better_together_platforms_on_external'

  def up
    return unless table_exists?(TABLE)

    add_column TABLE, :locality, :string, null: false, default: 'local' unless column_exists?(TABLE, :locality)
    add_index TABLE, :locality, name: LOCALITY_INDEX unless index_name_exists?(TABLE, LOCALITY_INDEX)
    execute "UPDATE #{TABLE} SET locality = 'remote' WHERE external IS TRUE" if column_exists?(TABLE, :external)
    remove_index TABLE, name: EXTERNAL_INDEX if index_name_exists?(TABLE, EXTERNAL_INDEX)
    remove_column TABLE, :external if column_exists?(TABLE, :external)
  end

  def down
    return unless table_exists?(TABLE)

    add_column TABLE, :external, :boolean, null: false, default: false unless column_exists?(TABLE, :external)
    add_index TABLE, :external, name: EXTERNAL_INDEX unless index_name_exists?(TABLE, EXTERNAL_INDEX)
    execute "UPDATE #{TABLE} SET external = TRUE WHERE locality = 'remote'" if column_exists?(TABLE, :locality)
    remove_index TABLE, name: LOCALITY_INDEX if index_name_exists?(TABLE, LOCALITY_INDEX)
    remove_column TABLE, :locality if column_exists?(TABLE, :locality)
  end
end
