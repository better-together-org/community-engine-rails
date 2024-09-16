# frozen_string_literal: true

require 'storext'

module BetterTogether
  module Content
    # Base class from which all other content blocks types inherit
    class Block < ApplicationRecord
      # include Searchable
      include ::Storext.model

      SUBCLASSES = [
        ::BetterTogether::Content::Image, ::BetterTogether::Content::Html,
        ::BetterTogether::Content::RichText, ::BetterTogether::Content::Template
      ].freeze

      has_many :page_blocks, foreign_key: :block_id, dependent: :destroy
      has_many :pages, through: :page_blocks

      store_attributes :accessibility_attributes do
        aria_label String, default: ''
        aria_hidden Boolean, default: false
        aria_describedby String, default: ''
        aria_live String, default: 'polite' # 'polite' or 'assertive'
        aria_role String, default: ''
        aria_controls String, default: ''
        aria_expanded Boolean, default: false
        aria_tabindex Integer, default: 0
      end

      store_attributes :content_data do
        # Add content-specific attributes here
      end

      store_attributes :content_settings do
        # Add content-specific settings here
      end

      store_attributes :data_attributes do
        data_controller String, default: ''
        data_action String, default: ''
        data_target String, default: ''
      end

      store_attributes :html_attributes do
        # Add HTML attributes here
      end

      store_attributes :layout_settings do
        # Add layout-related settings here
      end

      store_attributes :media_settings do
        attribution_url String, default: ''
      end

      store_attributes :style_settings do
        css_classes String, default: ''
        css_styles String, default: ''
      end

      validates :identifier,
                uniqueness: true,
                length: { maximum: 100 },
                allow_blank: true

      def identifier=(arg)
        super(arg.parameterize)
      end

      def to_partial_path
        "better_together/content/blocks/#{block_name}"
      end

      def self.block_name
        name.demodulize.underscore
      end

      def self.load_all_subclasses
        # rubocop:todo Layout/LineLength
        SUBCLASSES.each(&:connection) # Add all known subclasses here
        # rubocop:enable Layout/LineLength
      end

      def self.localized_block_attributes
        list = []

        descendants.each do |descendant|
          next unless descendant.respond_to? :localized_attribute_list

          list += descendant.localized_attribute_list
        end

        list.flatten
      end

      def self.storext_keys
        load_all_subclasses if Rails.env.development?
        BetterTogether::Content::Block.storext_definitions.keys +
        descendants.map {|child| child.storext_definitions.keys }.flatten
      end

      def self.extra_permitted_attributes
        load_all_subclasses if Rails.env.development?
        descendants.map {|child| child.extra_permitted_attributes }.flatten
      end

      def block_name
        self.class.block_name
      end

      def to_s
        "#{block_name} - #{if persisted?
                             identifier.present? ? identifier : id.split('-').first
                           else
                             'new'
                           end}"
      end
    end
  end
end
