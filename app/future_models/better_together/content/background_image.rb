# frozen_string_literal: true

module BetterTogether
  module Content
    # Allows the user to ceate and display image content
    class BackgroundImage < Medium
      # include ::BetterTogether::Content::BlockAttributes
      has_many :page_blocks, foreign_key: :block_id
      has_many :pages, through: :page_blocks

      def self.content_addable?
        false
      end

      def self.extra_permitted_attributes
        %i[ id type media creator_id _destroy ]
      end
    end
  end
end
