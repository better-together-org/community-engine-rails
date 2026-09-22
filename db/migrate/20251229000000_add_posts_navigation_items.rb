# frozen_string_literal: true

# Adds posts navigation items to header and host dropdown
class AddPostsNavigationItems < ActiveRecord::Migration[7.2]
  def up
    puts 'Adding posts navigation items...'

    header_area = ensure_navigation_area(
      identifier: 'platform-header',
      name: 'Platform Header',
      slug: 'platform-header'
    )

    header_posts = header_area.navigation_items.find_or_initialize_by(identifier: 'posts')
    header_posts.assign_attributes(
      title_en: I18n.t('navigation.header.posts', default: 'Posts'),
      slug_en: 'posts',
      position: 1,
      item_type: 'link',
      route_name: 'posts_url',
      visible: true,
      privacy: 'private',
      visibility_strategy: 'permission',
      permission_identifier: 'manage_platform',
      navigation_area: header_area
    )
    header_posts.save!

    host_area = ensure_navigation_area(
      identifier: 'platform-host',
      name: 'Platform Host',
      slug: 'platform-host'
    )

    host_nav = host_area.navigation_items.find_or_initialize_by(identifier: 'host-nav')
    host_nav.assign_attributes(
      title_en: 'Host',
      slug_en: 'host-nav',
      position: 0,
      visible: true,
      protected: true,
      item_type: 'dropdown',
      url: '#',
      privacy: 'private',
      visibility_strategy: 'permission',
      permission_identifier: 'view_metrics_dashboard',
      navigation_area: host_area
    )
    host_nav.save!

    host_posts = host_nav.children.find_or_initialize_by(identifier: 'host-posts')
    host_posts.assign_attributes(
      title_en: 'Posts',
      slug_en: 'host-posts',
      position: host_posts[:position] || next_child_position(host_nav),
      item_type: 'link',
      route_name: 'posts_url',
      privacy: 'private',
      visibility_strategy: 'permission',
      permission_identifier: 'manage_platform',
      visible: true,
      protected: true,
      navigation_area: host_area
    )
    host_posts.save!
  end

  def down
    # Remove posts navigation items
    BetterTogether::NavigationItem.where(identifier: %w[posts host-posts]).destroy_all
  end

  private

  def ensure_navigation_area(identifier:, name:, slug:)
    BetterTogether::NavigationArea.find_or_initialize_by(identifier:).tap do |area|
      area.name = name
      area.slug = slug
      area.visible = true
      area.protected = true
      area.save!
    end
  end

  def next_child_position(parent)
    parent.children.maximum(:position).to_i + 1
  end
end
