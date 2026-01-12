# frozen_string_literal: true

# Seeds new roles, permissions, assignments, and navigation items introduced after initial installs.
class SeedRbacAndNavigation < ActiveRecord::Migration[7.2]
  def up
    puts 'Seeding new RBAC roles, permissions, and navigation items...'

    load BetterTogether::Engine.root.join('lib', 'tasks', 'better_together', 'seed_rbac_and_navigation.rake')

    begin
      Rake::Task['better_together:seed:rbac_and_navigation'].invoke
    rescue RuntimeError
      Rake::Task['app:better_together:seed:rbac_and_navigation'].invoke
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Cannot safely remove seeded RBAC data and navigation items'
  end
end
