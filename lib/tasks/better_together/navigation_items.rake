# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
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

    desc 'Create or update posts navigation item in header (optional: POSTS_PRIVACY=public|private, default: public)'
    task create_header_posts_item: :environment do
      privacy = ENV['POSTS_PRIVACY'] || 'public'
      puts "Creating or updating posts navigation item in header (privacy: #{privacy})..."

      area = BetterTogether::NavigationArea.find_by(identifier: 'platform-header')
      unless area
        puts 'Platform Header navigation area not found. Run db:seed first.'
        exit 1
      end

      nav_item = area.navigation_items.find_or_initialize_by(
        identifier: 'posts'
      )

      # Base attributes for all privacy levels
      attributes = {
        title_en: I18n.t('navigation.header.posts', default: 'Posts'),
        slug_en: 'posts',
        position: 1,
        item_type: 'link',
        route_name: 'posts_url',
        visible: true,
        privacy: privacy,
        navigation_area: area
      }

      # Set visibility strategy based on privacy
      if privacy == 'private'
        attributes[:visibility_strategy] = 'permission'
        attributes[:permission_identifier] = 'manage_platform'
      else
        # For public items: privacy='public' allows access to EVERYONE (no login required).
        # visibility_strategy='authenticated' just satisfies the NOT NULL database constraint,
        # but the privacy check happens first and grants access to all users.
        # See NavigationItem#visible_to? method: "return true if privacy_public?"
        attributes[:visibility_strategy] = 'authenticated'
        attributes[:permission_identifier] = nil
      end

      nav_item.assign_attributes(attributes)

      if nav_item.save
        puts "Successfully #{nav_item.previously_new_record? ? 'created' : 'updated'} posts navigation item in header"
      else
        puts "Failed to save posts navigation item: #{nav_item.errors.full_messages.join(', ')}"
        exit 1
      end
    end

    desc 'Create or update posts navigation item in host dropdown'
    task create_host_posts_item: :environment do
      puts 'Creating or updating posts navigation item in host dropdown...'

      area = BetterTogether::NavigationArea.find_by(identifier: 'platform-host')
      unless area
        puts 'Platform Host navigation area not found. Run db:seed first.'
        exit 1
      end

      host_nav = area.navigation_items.find_by(identifier: 'host-nav')
      unless host_nav
        puts 'Host dropdown navigation item not found. Run db:seed first.'
        exit 1
      end

      nav_item = host_nav.children.find_or_initialize_by(
        identifier: 'host-posts'
      )

      # Find the next available position if the item is new
      if nav_item.new_record?
        max_position = host_nav.children.maximum(:position) || 0
        nav_item.position = max_position + 1
      end

      # Match navigation builder: base attributes + merge(visible: true, protected: true, navigation_area: area)
      nav_item.assign_attributes(
        title_en: 'Posts',
        slug_en: 'host-posts',
        item_type: 'link',
        route_name: 'posts_url',
        privacy: 'private',
        visibility_strategy: 'permission',
        permission_identifier: 'manage_platform',
        visible: true,
        protected: true,
        navigation_area: area
      )

      if nav_item.save
        puts "Successfully #{nav_item.previously_new_record? ? 'created' : 'updated'} posts navigation item in host dropdown"
      else
        puts "Failed to save posts navigation item: #{nav_item.errors.full_messages.join(', ')}"
        exit 1
      end
    end

    # Helper method to determine if nav item should be public
    def should_be_public?(nav_item)
      # If the visible boolean is true, make it public
      nav_item.visible?
    end
  end
end
# rubocop:enable Metrics/BlockLength
