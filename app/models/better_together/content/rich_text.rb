# frozen_string_literal: true

module BetterTogether
  module Content
    # Uses Trix editor and Active Storage to allow user to create and display rich text content
    class RichText < Block
      include Translatable

      has_many :page_blocks, foreign_key: :block_id, dependent: :destroy
      has_many :pages, through: :page_blocks

      translates :content, backend: :action_text
    end
  end
end
