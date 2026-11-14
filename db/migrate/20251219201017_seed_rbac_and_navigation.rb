# frozen_string_literal: true

# Seeds new roles, permissions, assignments, and navigation items introduced after initial installs.
class SeedRbacAndNavigation < ActiveRecord::Migration[7.2]
  def up
    return if fresh_install?

    puts 'Seeding new RBAC roles, permissions, and navigation items...'

    run_engine_rake_task('better_together:seed:rbac_and_navigation', file: 'seed_rbac_and_navigation.rake',
                                                                     skip_when_empty: %i[better_together_platforms])
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Cannot safely remove seeded RBAC data and navigation items'
  end

  private

  # An empty database (migrated from zero) has nothing to backfill; the seed builders
  # create these records during setup, and the app models need later columns anyway.
  def fresh_install?
    !table_exists?(:better_together_roles) ||
      select_value('SELECT 1 FROM better_together_roles LIMIT 1').nil?
  end
end
