# frozen_string_literal: true

module BetterTogether
  # Represents a blog post
  class Post < ApplicationRecord
    include Attachments::Images
    include Authorable
    include BlockFilterable
    include FriendlySlug
    include Categorizable
    include Creatable
    include Identifier
    include Metrics::Viewable
    include Privacy
    include Publishable
    include Searchable
    include Seedable
    include TrackedActivity

    attachable_cover_image

    categorizable

    belongs_to :platform, class_name: 'BetterTogether::Platform', optional: true

    translates :title, type: :string
    alias name title
    translates :content, backend: :action_text

    settings index: default_elasticsearch_index

    slugged :title

    validates :title,
              presence: true

    validates :content,
              presence: true
    validates :source_id, uniqueness: { scope: :platform_id }, allow_blank: true

    before_validation :assign_current_platform_if_available

    # Automatically grant the post creator an authorship record
    after_create :add_creator_as_author

    def to_s
      title
    end

    def mirrored?
      source_id.present? || platform&.external?
    end

    def preserved_remote_uuid?
      source_id.blank? && platform&.external?
    end

    def source_identifier
      source_id.presence || id
    end

    def local_to_platform?(local_platform = Current.platform)
      return true if platform_id.blank?
      return false unless local_platform

      platform_id == local_platform.id
    end

    def remote_to_platform?(local_platform = Current.platform)
      mirrored? && !local_to_platform?(local_platform)
    end

    configure_attachment_cleanup

    # Customize the data sent to Elasticsearch for indexing
    def as_indexed_json(_options = {})
      as_json(
        only: [:id],
        methods: [:title, :name, :slug, *self.class.localized_attribute_list.keep_if do |a|
          a.starts_with?('title' || a.starts_with?('slug') || a.starts_with?('content'))
        end]
      )
    end

    private

    def add_creator_as_author
      return unless respond_to?(:creator_id) && creator_id.present?

      authorships.find_or_create_by(author_id: creator_id)
    end

    def assign_current_platform_if_available
      return unless has_attribute?(:platform_id)
      return if platform_id.present?
      return unless Current.platform

      self.platform = Current.platform
    end
  end
end
