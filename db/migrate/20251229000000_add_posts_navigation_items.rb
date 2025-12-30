# frozen_string_literal: true

# Adds posts navigation items to header and host dropdown
class AddPostsNavigationItems < ActiveRecord::Migration[7.2]
  def up
    puts 'Adding posts navigation items...'

    load BetterTogether::Engine.root.join('lib', 'tasks', 'better_together', 'navigation_items.rake')

    # Set header posts privacy to 'private' for platform managers only during this migration.
    # The navigation_items rake task defaults POSTS_PRIVACY to 'public'; here we override that default to 'private' for security,
    # so posts navigation is initially restricted to platform managers. Platform organizers can later change it to 'public'
    # via the admin interface.
    ENV['POSTS_PRIVACY'] = 'private'

    begin
      Rake::Task['better_together:navigation_items:create_header_posts_item'].invoke
    rescue RuntimeError
      Rake::Task['app:better_together:navigation_items:create_header_posts_item'].invoke
    end

    ENV.delete('POSTS_PRIVACY')

    # Host posts is always private (no env var needed)
    begin
      Rake::Task['better_together:navigation_items:create_host_posts_item'].invoke
    rescue RuntimeError
      Rake::Task['app:better_together:navigation_items:create_host_posts_item'].invoke
    end
  end

  def down
    # Remove posts navigation items
    BetterTogether::NavigationItem.where(identifier: %w[posts host-posts]).destroy_all
  end
end
