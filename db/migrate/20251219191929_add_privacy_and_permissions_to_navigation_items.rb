# frozen_string_literal: true

# Add privacy and permission-based visibility to navigation items
class AddPrivacyAndPermissionsToNavigationItems < ActiveRecord::Migration[7.2]
  def change
    change_table :better_together_navigation_items do |t|
      # Add privacy column using bt_ helper (defaults to 'private' like all BT models)
      t.bt_privacy

      # Simple permission identifier check (e.g., 'view_metrics_dashboard')
      # Only used when privacy is not 'public'
      t.string :permission_identifier

      # Visibility strategy: 'permission', 'authenticated'
      # Only shown in UI when privacy is not 'public'
      # Defaults to 'authenticated' for backward compatibility
      t.string :visibility_strategy, default: 'authenticated', null: false
    end

    add_index :better_together_navigation_items, :permission_identifier
    add_index :better_together_navigation_items, :visibility_strategy

    # Set existing visible nav items to public for backward compatibility
    reversible do |dir|
      dir.up do
        puts 'Setting existing visible navigation items to public...'

        # Use Arel for database-agnostic queries
        nav_items = BetterTogether::NavigationItem.arel_table
        pages = BetterTogether::Page.arel_table

        # Update visible items to public
        visible_update = Arel::UpdateManager.new
                                            .table(nav_items)
                                            .set([[nav_items[:privacy], 'public']])
                                            .where(nav_items[:visible].eq(true))

        connection.execute(visible_update.to_sql)

        # Build join for published pages
        join = nav_items.join(pages)
                        .on(
                          nav_items[:linkable_type].eq('BetterTogether::Page')
                            .and(nav_items[:linkable_id].eq(pages[:id]))
                        )

        # Update items linked to published pages
        published_pages_update = Arel::UpdateManager.new
                                                    .table(nav_items)
                                                    .set([[nav_items[:privacy], 'public']])
                                                    .where(
                                                      nav_items[:linkable_type].eq('BetterTogether::Page')
                                                        .and(
                                                          nav_items[:linkable_id].in(
                                                            pages.project(pages[:id])
                                                                 .where(pages[:published_at].not_eq(nil))
                                                                 .where(pages[:published_at].lteq(Time.current))
                                                          )
                                                        )
                                                    )

        connection.execute(published_pages_update.to_sql)

        updated_count = connection.select_value(
          nav_items.project(Arel.star.count)
                   .where(nav_items[:privacy].eq('public'))
                   .to_sql
        )
        puts "Updated #{updated_count} navigation items to public"
      end
    end
  end
end
