# frozen_string_literal: true

require 'storext'

module BetterTogether
  # Represents the host application and it's peers
  class Platform < ApplicationRecord
    include Host
    include Identifier
    include Joinable
    include Permissible
    include PrimaryCommunity
    include Privacy
    include Protected
    include ::Storext.model

    joinable joinable_type: 'platform',
             member_type: 'person'

    has_many :invitations,
             class_name: '::BetterTogether::PlatformInvitation',
             foreign_key: :invitable_id

    slugged :name

    store_attributes :settings do
      requires_invitation Boolean, default: false
    end

    validates :url, presence: true, uniqueness: true
    validates :time_zone, presence: true

    has_one_attached :profile_image
    has_one_attached :cover_image

    has_many :platform_blocks, dependent: :destroy, class_name: 'BetterTogether::Content::PlatformBlock'
    has_many :blocks, through: :platform_blocks

    # Virtual attributes to track removal
    attr_accessor :remove_profile_image, :remove_cover_image

    # Callbacks to remove images if necessary
    before_save :purge_profile_image, if: -> { remove_profile_image == '1' }
    before_save :purge_cover_image, if: -> { remove_cover_image == '1' }

    def css_block
      @css_block ||= blocks.find_by(type: 'BetterTogether::Content::Css')
    end

    def css_block?
      css_block.present?
    end

    def css_block_attributes= attrs={}
      block = blocks.find_by(type: 'BetterTogether::Content::Css')
      if block
        block.update(attrs.except(:type))
      else
        self.platform_blocks.build(block: BetterTogether::Content::Css.new(attrs.except(:type)))
      end
    end

    def primary_community_extra_attrs
      { host:, protected: }
    end

    def to_s
      name
    end
  end
end
