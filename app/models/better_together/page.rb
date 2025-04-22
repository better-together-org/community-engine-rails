# frozen_string_literal: true

module BetterTogether
  # An informational document used to display custom content to the user
  class Page < ApplicationRecord
    include Authorable
    include Categorizable
    include Identifier
    include Protected
    include Privacy
    include Searchable

    PAGE_LAYOUTS = [
      'layouts/better_together/page',
      'layouts/better_together/page_with_nav',
      'layouts/better_together/full_width_page'
    ].freeze

    has_many :page_blocks, -> { positioned }, dependent: :destroy, class_name: 'BetterTogether::Content::PageBlock'
    has_many :blocks, through: :page_blocks
    has_many :image_blocks, -> { where(type: 'BetterTogether::Content::Image') }, through: :page_blocks, source: :block
    has_many :rich_text_blocks, lambda {
      where(type: 'BetterTogether::Content::RichText')
    }, through: :page_blocks, source: :block

    belongs_to :sidebar_nav, class_name: 'BetterTogether::NavigationArea', optional: true

    accepts_nested_attributes_for :page_blocks, allow_destroy: true

    translates :title, type: :string
    translates :content, backend: :action_text

    settings index: default_elasticsearch_index

    slugged :title, min_length: 1

    # Validations
    validates :title, presence: true
    validates :layout, inclusion: { in: PAGE_LAYOUTS }, allow_blank: true

    # Scopes
    scope :published, -> { where.not(published_at: nil).where('published_at <= ?', Time.zone.now) }
    scope :by_publication_date, -> { order(published_at: :desc) }

    def hero_block
      # rubocop:todo Layout/LineLength
      @hero_block ||= blocks.where(type: 'BetterTogether::Content::Hero').with_attached_background_image_file.with_translations.first
      # rubocop:enable Layout/LineLength
    end

    def content_blocks
      # rubocop:todo Layout/LineLength
      @content_blocks ||= blocks.where.not(type: 'BetterTogether::Content::Hero').with_attached_background_image_file.with_translations
      # rubocop:enable Layout/LineLength
    end

    # Customize the data sent to Elasticsearch for indexing
    def as_indexed_json(_options = {}) # rubocop:todo Metrics/MethodLength
      as_json(
        only: [:id],
        methods: [:title, :name, :slug, *self.class.localized_attribute_list.keep_if do |a|
          a.starts_with?('title' || a.starts_with?('slug'))
        end],
        include: {
          rich_text_blocks: {
            only: %i[id],
            methods: [:indexed_localized_content]
          }
        }
      )
    end

    # Needed for elasticsearch results to work properly (April 22, 2025)
    def name
      title
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
  end
end
