# frozen_string_literal: true

require 'storext'

module BetterTogether
  # Represents a blog post
  class Post < ApplicationRecord
    include Attachments::Images
    include Authorable
    include BlockFilterable
    include Claimable
    include FriendlySlug
    include Categorizable
    include Citable
    include Creatable
    include Identifier
    include Metrics::Viewable
    include Privacy
    include Publishable
    include Searchable
    include Seedable
    include TrackedActivity
    include ::Storext.model

    attachable_cover_image

    categorizable

    belongs_to :platform, class_name: 'BetterTogether::Platform', optional: true

    store_attributes :display_settings do
      contributors_display_visibility String, default: 'inherit'
    end

    translates :title, type: :string
    alias name title
    translates :content, backend: :action_text

    slugged :title

    searchable pg_search: {
      against: [:identifier],
      using: {
        tsearch: {
          prefix: true,
          dictionary: 'simple'
        }
      }
    }

    validates :title,
              presence: true

    validates :content,
              presence: true
    validates :platform_id, presence: true
    validates :source_id, uniqueness: { scope: :platform_id }, allow_blank: true
    validates :contributors_display_visibility,
              inclusion: { in: BetterTogether::Authorable::CONTRIBUTOR_DISPLAY_VISIBILITIES }

    scope :latest_first, lambda {
      order(
        Arel.sql('COALESCE(better_together_posts.published_at, better_together_posts.created_at) DESC'),
        arel_table[:created_at].desc
      )
    }

    def self.card_render_includes
      includes = [
        :string_translations,
        { cover_image_attachment: :blob },
        { contributions: :author },
        { categories: { cover_image_attachment: :blob } }
      ]

      rich_text_association = reflect_on_association(:rich_text_content)&.name
      includes << rich_text_association if rich_text_association

      includes
    end

    before_validation :assign_current_platform_if_available

    # Automatically grant the post creator an authorship record only when no
    # explicit human or robot authors were selected during creation.
    after_commit :add_creator_as_author, on: :create

    def self.extra_permitted_attributes
      super + %i[contributors_display_visibility]
    end

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

    private

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
