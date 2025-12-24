# frozen_string_literal: true

namespace :better_together do
  namespace :navigation_items do
    desc 'Set privacy to public for existing visible navigation items'
    task set_public_privacy: :environment do
      puts 'Updating existing navigation items privacy settings...'

      # Count for reporting
      updated_count = 0
      skipped_count = 0

      BetterTogether::NavigationItem.find_each do |nav_item|
        # Only update items that don't already have privacy set (will be 'private' default)
        # Check if item is/should be visible
        if should_be_public?(nav_item)
          nav_item.update_column(:privacy, 'public')
          updated_count += 1
        else
          # Keep as private but mark we processed it
          skipped_count += 1
        end
      end

      puts "Updated #{updated_count} navigation items to public"
      puts "Skipped #{skipped_count} navigation items (keeping private)"
      puts 'Done!'
    end

    # Helper method to determine if nav item should be public
    def should_be_public?(nav_item)
      # If the visible boolean is true, make it public
      nav_item.visible?
    end
  end
end
