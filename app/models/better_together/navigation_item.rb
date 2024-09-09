# frozen_string_literal: true

module BetterTogether
  # An element in a navigation tree. Links to an internal or external page
  class NavigationItem < ApplicationRecord # rubocop:todo Metrics/ClassLength
    include Identifier
    include Positioned
    include Protected

    belongs_to :navigation_area
    belongs_to :linkable, polymorphic: true, optional: true, autosave: true

    # Association with parent item
    belongs_to :parent,
               class_name: 'NavigationItem',
               optional: true

    # Association with child items
    has_many :children,
             lambda {
               positioned
             },
             class_name: 'NavigationItem',
             foreign_key: 'parent_id',
             dependent: :destroy

    # Define valid linkable classes
    LINKABLE_CLASSES = [
      'BetterTogether::Page'
    ].freeze

    ROUTE_NAMES = {
      communities: 'communities_path',
      geography_continents: 'geography_continents_path',
      geography_countries: 'geography_countries_path',
      geography_states: 'geography_states_path',
      geography_regions: 'geography_regions_path',
      geography_settlements: 'geography_settlements_path',
      host_dashboard: 'host_dashboard_path',
      navigation_areas: 'navigation_areas_path',
      pages: 'pages_path',
      people: 'people_path',
      platforms: 'platforms_path',
      resource_permissions: 'resource_permissions_path',
      roles: 'roles_path',
      users: 'users_path'
    }.freeze

    slugged :title

    translates :title, type: :string

    validates :title, presence: true, length: { maximum: 255 }
    validates :url,
              format: { with: %r{\A(http|https)://.+\z|\A#\z|^/*[\w/-]+}, allow_blank: true,
                        message: 'must be a valid URL, "#", or an absolute path' }
    validates :visible, inclusion: { in: [true, false] }
    validates :item_type, inclusion: { in: %w[link dropdown separator], allow_blank: true }
    validates :linkable_type, inclusion: { in: LINKABLE_CLASSES, allow_nil: true }

    # Scope to return top-level navigation items
    scope :top_level, -> { where(parent_id: nil) }

    scope :visible, -> { where(visible: true) }

    def build_children(pages, navigation_area) # rubocop:todo Metrics/MethodLength
      pages.each_with_index do |page, index|
        children.build(
          navigation_area:,
          title: page.title,
          slug: page.slug,
          position: index,
          visible: true,
          protected: true,
          item_type: 'link',
          url: '',
          linkable: page
        )
      end
    end

    def child?
      parent_id.present?
    end

    def dropdown?
      item_type == 'dropdown'
    end

    def item_type
      return read_attribute(:item_type) if persisted? || read_attribute(:item_type).present?

      'link'
    end

    def linkable_id=(arg)
      self[:linkable_type] = ('BetterTogether::Page' if arg.present?)
      super
    end

    def set_position
      return read_attribute(:position) if persisted? || read_attribute(:position).present?

      max_position = navigation_area.navigation_items.maximum(:position)
      max_position ? max_position + 1 : 0
    end

    def title
      return super unless linkable.present? && linkable.respond_to?(:title)

      linkable.title
    end

    def title=(arg)
      linkable.title = arg if linkable.present? && linkable.respond_to?(:title=)

      super
    end

    def url
      _url = '#'

      if linkable.present?
        linkable.url
      elsif route_name.present? # If the route_name is present, use the dynamic route
        retrieve_route(route_name)
      else
        read_attribute(:url) or _url
      end
    end

    def url=(arg)
      if linkable.present? || route_name.present?
        self[:url] = nil
      else
        super
      end
    end

    def visible
      if linkable.is_a?(BetterTogether::Page)
        linkable.published?
      else
        super
      end
    end

    def visible?
      visible
    end

    private

    def retrieve_route(route)
      # Use `send` to dispatch the correct URL helper
      Rails.application.routes.url_helpers.public_send(route, locale: I18n.locale)
    rescue NoMethodError
      begin
        BetterTogether::Engine.routes.url_helpers.public_send(route, locale: I18n.locale)
      rescue NoMethodError
        Rails.logger.error("Invalid route name: #{route}")
        nil
      end
    end
  end
end
