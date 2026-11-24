# frozen_string_literal: true

# Adds navigation items that the default navigation packet gained after a platform was installed
# (host review pages, jobs and the Billing menu). Existing items are left as stewards set them.
# When a route or packet item is added later, add a migration like this one that runs the same task.
class EnsurePacketNavigationItems < ActiveRecord::Migration[7.2]
  def up
    return unless table_exists?(:better_together_navigation_items)

    run_engine_rake_task('better_together:navigation:ensure', file: 'navigation_ensure.rake',
                                                              skip_when_empty: %i[better_together_navigation_items])
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Seeded navigation items are not removed automatically'
  end
end
