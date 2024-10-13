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
      content_blocks: 'content_blocks_path',
      communities: 'communities_path',
      geography_continents: 'geography_continents_path',
      geography_countries: 'geography_countries_path',
      geography_states: 'geography_states_path',
      geography_regions: 'geography_regions_path',
      geography_settlements: 'geography_settlements_path',
      host_dashboard: 'host_dashboard_path',
      metrics_reports: 'metrics_reports_path',
      navigation_areas: 'navigation_areas_path',
      pages: 'pages_path',
      people: 'people_path',
      platforms: 'platforms_path',
      resource_permissions: 'resource_permissions_path',
      roles: 'roles_path',
      users: 'users_path'
    }.freeze

    def self.route_name_paths
      ROUTE_NAMES.values.map(&:to_s)
    end

    translates :title, type: :string

    slugged :title

    validates :title, presence: true, length: { maximum: 255 }
    validates :url,
              format: { with: %r{\A(http|https)://.+\z|\A#\z|^/*[\w/-]+}, allow_blank: true,
                        message: 'must be a valid URL, "#", or an absolute path' }
    validates :visible, inclusion: { in: [true, false] }
    validates :item_type, inclusion: { in: %w[link dropdown separator], allow_blank: true }
    validates :linkable_type, inclusion: { in: LINKABLE_CLASSES, allow_nil: true }
    validates :route_name, inclusion: { in: ->(item) { item.class.route_name_paths }, allow_nil: true, allow_blank: true }

    # Scope to return top-level navigation items
    scope :top_level, -> { where(parent_id: nil) }

    scope :visible, -> {
      navigation_items = arel_table
      pages = BetterTogether::Page.arel_table

      # Construct the LEFT OUTER JOIN condition
      join_condition = navigation_items[:linkable_type].eq('BetterTogether::Page').and(navigation_items[:linkable_id].eq(pages[:id]))
      join = navigation_items
              .join(pages, Arel::Nodes::OuterJoin)
              .on(join_condition)
              .join_sources

      # Define the conditions
      visible_flag = navigation_items[:visible].eq(true)
      not_page = navigation_items[:linkable_type].not_eq('BetterTogether::Page')
      published_page = pages[:published_at].lteq(Time.zone.now)

      # Handle navigation items without a linkable by checking for NULL
      linkable_is_nil = navigation_items[:linkable_id].eq(nil)

      # Combine the conditions: visible_flag AND (not_page OR published_page OR linkable is nil)
      combined_conditions = visible_flag.and(not_page.or(published_page).or(linkable_is_nil))

      # Apply the join and where conditions
      joins(join)
        .where(combined_conditions)
    }

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

    def dropdown_with_visible_children?
      dropdown? and children.visible.any?
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

    def title(options = {}, locale: I18n.locale)
      return linkable.title(**options) if linkable.present? && linkable.respond_to?(:title)
      super(**options)
    end

    def title=(arg, options = {}, locale: I18n.locale)
      linkable.public_send :title=, arg, locale: locale, **options if linkable.present? && linkable.respond_to?(:title=)

      super(arg, locale: locale, **options)
    end

    def url
      fallback_url = '#'

      if linkable.present?
        linkable.url
      elsif route_name.present? # If the route_name is present, use the dynamic route
        retrieve_route(route_name)
      else
        read_attribute(:url) or fallback_url
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
