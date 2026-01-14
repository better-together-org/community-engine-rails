# frozen_string_literal: true

require 'storext'

module BetterTogether
  # Represents the host application and it's peers
  class Platform < ApplicationRecord
    include PlatformHost
    include Creatable
    include Identifier
    include Joinable
    include Metrics::Viewable
    include Permissible
    include PrimaryCommunity
    include Privacy
    include Protected
    include ::Storext.model

    has_community

    joinable joinable_type: 'platform',
             member_type: 'person'

    has_many :invitations,
             class_name: '::BetterTogether::PlatformInvitation',
             foreign_key: :invitable_id

    # For performance - scope to limit invitations in some contexts
    has_many :recent_invitations,
             -> { where(created_at: 30.days.ago..) },
             class_name: '::BetterTogether::PlatformInvitation',
             foreign_key: :invitable_id

    slugged :name

    store_attributes :settings do
      requires_invitation Boolean, default: false
    end

    # Alias the database url column to host_url for clarity
    alias_attribute :host_url, :url

    validates :host_url, presence: true, uniqueness: true,
                         format: URI::DEFAULT_PARSER.make_regexp(%w[http https])
    validates :time_zone, presence: true
    validates :external, inclusion: { in: [true, false] }

    scope :external, -> { where(external: true) }
    scope :internal, -> { where(external: false) }
    scope :oauth_providers, -> { external }

    has_one_attached :profile_image
    has_one_attached :cover_image

    has_one :sitemap, class_name: '::BetterTogether::Sitemap', dependent: :destroy

    has_many :platform_blocks, dependent: :destroy, class_name: 'BetterTogether::Content::PlatformBlock'
    has_many :blocks, through: :platform_blocks

    # Virtual attributes to track removal
    attr_accessor :remove_profile_image, :remove_cover_image

    # Callbacks to remove images if necessary
    before_save :purge_profile_image, if: -> { remove_profile_image == '1' }
    before_save :purge_cover_image, if: -> { remove_cover_image == '1' }

    def cache_key
      "#{super}/#{css_block&.updated_at&.to_i}"
    end

    # Return the routing URL for this platform (used by metrics tracking)
    # Returns nil for new records that haven't been persisted yet
    def url
      return nil unless persisted?

      BetterTogether::Engine.routes.url_helpers.platform_url(self, locale: I18n.locale)
    end

    # rubocop:todo Layout/LineLength
    # TODO: Updating the css_block contents does not update the platform cache key. Needs platform attribute update before changes take effect.
    # rubocop:enable Layout/LineLength
    def css_block
      @css_block ||= blocks.find_by(type: 'BetterTogether::Content::Css')
    end

    def css_block?
      css_block.present?
    end

    def css_block_attributes=(attrs = {})
      # Clear memoized css_block to ensure we get the latest state
      @css_block = nil

      new_attrs = attrs.except(:type).merge(protected: true, privacy: 'public')

      block = blocks.find_by(type: 'BetterTogether::Content::Css')
      if block
        # Update the existing block directly and save it
        block.update!(new_attrs)
        @css_block = block
      else
        # Platform CSS blocks should be protected from deletion
        new_block = BetterTogether::Content::Css.new(new_attrs)
        platform_blocks.build(block: new_block)
        @css_block = new_block
      end
    end

    def primary_community_extra_attrs
      { host:, protected: }
    end

    # Efficiently load platform memberships with all necessary associations
    # to prevent N+1 queries in views
    def memberships_with_associations # rubocop:todo Metrics/MethodLength
      person_platform_memberships.includes(
        {
          member: [
            :string_translations,
            :text_translations,
            { profile_image_attachment: { blob: { variant_records: [], preview_image_attachment: { blob: [] } } } }
          ]
        },
        {
          role: %i[
            string_translations
            text_translations
          ]
        }
      )
    end

    def to_s
      name
    end
  end
end
