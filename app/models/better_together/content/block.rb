# frozen_string_literal: true

require 'storext'

module BetterTogether
  module Content
    # Base class from which all other content blocks types inherit
    class Block < ApplicationRecord
      # include Searchable
      include ::BetterTogether::Content::BlockAttributes

      SUBCLASSES = [
        ::BetterTogether::Content::Image, ::BetterTogether::Content::Hero, ::BetterTogether::Content::Html,
        ::BetterTogether::Content::RichText, ::BetterTogether::Content::Template
      ].freeze

      has_many :page_blocks, foreign_key: :block_id, dependent: :destroy
      has_many :pages, through: :page_blocks

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

      # Code to be run for each child class
      def self.inherited(subclass)
        super
        # Your custom logic here, which will be available to all subclasses
        subclass.instance_eval do
          include ::BetterTogether::Content::BlockAttributes
        end
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
