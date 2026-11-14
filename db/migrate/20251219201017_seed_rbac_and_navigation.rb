# frozen_string_literal: true

# Seeds new roles, permissions, assignments, and navigation items introduced after initial installs.
class SeedRbacAndNavigation < ActiveRecord::Migration[7.2]
  def up
    puts 'Seeding new RBAC roles, permissions, and navigation items...'

    run_engine_rake_task('better_together:seed:rbac_and_navigation', file: 'seed_rbac_and_navigation.rake',
                                                                     skip_when_empty: %i[better_together_platforms])
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Cannot safely remove seeded RBAC data and navigation items'
  end
end
