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
    validates :platform_id, presence: true
    validates :source_id, uniqueness: { scope: :platform_id }, allow_blank: true

    scope :latest_first, lambda {
      order(
        Arel.sql('COALESCE(better_together_posts.published_at, better_together_posts.created_at) DESC'),
        arel_table[:created_at].desc
      )
    }

    before_validation :assign_current_platform_if_available

    # Automatically grant the post creator an authorship record only when no
    # explicit human or robot authors were selected during creation.
    after_commit :add_creator_as_author, on: :create

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
        methods: [:title, :name, :slug, *self.class.localized_attribute_names_for_search.select do |attribute|
          attribute.start_with?('title', 'slug', 'content')
        end]
      )
    end

    private

    def add_creator_as_author
      return unless respond_to?(:creator_id) && creator_id.present?
      return if authorships.exists?

      authorships.find_or_create_by(author: creator)
    end

    def assign_current_platform_if_available
      return unless has_attribute?(:platform_id)
      return if platform_id.present?

      resolved = Current.platform ||
                 BetterTogether::Platform.find_by(host: true) ||
                 BetterTogether::Platform.first
      self.platform = resolved if resolved
    end
  end
end
