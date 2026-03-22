# frozen_string_literal: true

require 'storext'

module BetterTogether
  # An informational document used to display custom content to the user
  class Page < ApplicationRecord # rubocop:disable Metrics/ClassLength
    include Authorable
    # When adding authors via `author_ids=` or association ops, controllers can
    # set BetterTogether::Authorship.creator_context_id = current_person.id
    # to stamp newly-created authorships with the acting person.
    include Categorizable
    include Creatable
    include Identifier
    include Metrics::Viewable
    include Protected
    include Privacy
    include Publishable
    include Searchable
    include TrackedActivity
    include ::Storext.model

    belongs_to :community, class_name: 'BetterTogether::Community', optional: true

    before_validation :sync_name_and_title
    before_validation :assign_host_community

    categorizable

    PAGE_LAYOUTS = [
      'layouts/better_together/page',
      'layouts/better_together/page_with_nav',
      'layouts/better_together/full_width_page'
    ].freeze

    store_attributes :display_settings do
      show_title Boolean, default: true
    end

    has_many :page_blocks, -> { positioned }, dependent: :destroy, class_name: 'BetterTogether::Content::PageBlock'
    has_many :blocks, through: :page_blocks
    has_many :image_blocks, -> { where(type: 'BetterTogether::Content::Image') }, through: :page_blocks, source: :block
    has_many :markdown_blocks, lambda {
      where(type: 'BetterTogether::Content::Markdown')
    }, through: :page_blocks, source: :block
    has_many :rich_text_blocks, lambda {
      where(type: 'BetterTogether::Content::RichText')
    }, through: :page_blocks, source: :block
    has_many :template_blocks, lambda {
      where(type: 'BetterTogether::Content::Template')
    }, through: :page_blocks, source: :block

    # Navigation items that link to this page (polymorphic linkable association)
    has_many :navigation_items,
             as: :linkable,
             class_name: 'BetterTogether::NavigationItem',
             dependent: :nullify

    belongs_to :sidebar_nav, class_name: 'BetterTogether::NavigationArea', optional: true
    belongs_to :creator, class_name: 'BetterTogether::Person', optional: true

    accepts_nested_attributes_for :page_blocks, allow_destroy: true

    translates :title, type: :string
    alias name title

    translates :content, backend: :action_text

    settings index: default_elasticsearch_index

    slugged :title, min_length: 1

    self.parameterize_slug = false # Allows us to keep forward slashes in the slug (for now)

    # Validations
    validates :title, presence: true
    validates :layout, inclusion: { in: PAGE_LAYOUTS }, allow_blank: true

    # Automatically grant the page creator an authorship record
    after_create :add_creator_as_author

    # Touch associated navigation_items to invalidate navigation cache when page title changes
    # Use title_previously_changed? for Mobility-translated attributes
    after_save :touch_navigation_items, if: :title_previously_changed?

    # Update updated_at when title translation changes (for touch: true on navigation_items)
    # This is needed because Mobility stores translations in a separate table
    after_save :update_timestamp_for_title_change, if: :title_previously_changed?

    # Scopes
    scope :published, -> { where.not(published_at: nil).where('published_at <= ?', Time.zone.now) }
    scope :by_publication_date, -> { order(published_at: :desc) }

    after_commit :refresh_sitemap, on: %i[create update destroy]

    def hero_block
      @hero_block ||= blocks.where(type: 'BetterTogether::Content::Hero').with_attached_background_image_file.with_translations.first
    end

    def content_blocks
      @content_blocks ||= blocks.where.not(type: 'BetterTogether::Content::Hero').with_attached_background_image_file.with_translations
    end

    # Customize the data sent to Elasticsearch for indexing
    def as_indexed_json(_options = {}) # rubocop:todo Metrics/MethodLength
      json = as_json(
        only: [:id],
        methods: [:title, :name, :slug, *self.class.localized_attribute_list.keep_if do |a|
          a.starts_with?('title' || a.starts_with?('slug'))
        end],
        include: {
          markdown_blocks: {
            only: %i[id],
            methods: [:as_indexed_json]
          },
          rich_text_blocks: {
            only: %i[id],
            methods: [:indexed_localized_content]
          },
          template_blocks: {
            only: %i[id],
            methods: [:indexed_localized_content]
          }
        }
      )

      # Include rendered template content if page has template attribute
      if template.present?
        json['template_content'] = BetterTogether::TemplateRendererService.new(template).render_for_all_locales
      end

      json
    end

    def primary_image
      hero_block&.background_image_file
    end

    def published?
      published_at.present? && published_at < Time.zone.now
    end

    def select_option_title
      "#{title} (#{slug})"
    end

    def to_s
      title
    end

    def url
      "#{::BetterTogether.base_url_with_locale}/#{slug}"
    end

    private

    def refresh_sitemap
      return if Rails.env.test?

      SitemapRefreshJob.perform_later
    end

    def sync_name_and_title
      self.name = title if respond_to?(:name) && name.blank? && title.present?
      self.title = name if title.blank? && name.present?
    end

    def assign_host_community
      return unless has_attribute?(:community_id)
      return if community.present?

      self.community ||= BetterTogether::Community.find_by(host: true)
      self.community ||= host_platform_community
    end

    def host_platform_community
      host_platform_community_id = BetterTogether::Platform.where(host: true).limit(1).pluck(:community_id).first
      return unless host_platform_community_id

      BetterTogether::Community.find_by(id: host_platform_community_id)
    end

    def add_creator_as_author
      return unless respond_to?(:creator_id) && creator_id.present?

      authorships.find_or_create_by(author_id: creator_id)
    end

    # Touch navigation areas for all navigation items that link to this page
    # to invalidate their navigation area cache. We only touch each distinct
    # navigation area once to avoid redundant writes when multiple items in
    # the same area link to this page.
    def touch_navigation_items
      return if BetterTogether.skip_navigation_touches

      navigation_area_ids = navigation_items.select(:navigation_area_id).distinct.pluck(:navigation_area_id).compact
      return if navigation_area_ids.empty?

      BetterTogether::NavigationArea.where(id: navigation_area_ids).find_each do |navigation_area|
        navigation_area.touch
      rescue ActiveRecord::StaleObjectError
        # Retry once with a fresh reload
        navigation_area.reload.touch
      end
    end

    # Update the page's updated_at timestamp when title translation changes
    # This is needed because Mobility stores translations in a separate table,
    # so changing the title doesn't automatically update the Page's updated_at.
    # This allows the touch: true on navigation_items to work correctly.
    def update_timestamp_for_title_change
      # Skip callbacks and validations but update the timestamp
      # Then manually touch associated navigation items
      update_columns(updated_at: Time.current)

      # Manually trigger touch on navigation items since update_columns bypasses callbacks
      navigation_items.find_each(&:touch)
    end
  end
end
