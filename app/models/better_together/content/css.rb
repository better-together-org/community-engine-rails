# frozen_string_literal: true

module BetterTogether
  module Content
    # Renders raw html from an attribute
    class Css < Block
      has_many :page_blocks, foreign_key: :block_id, dependent: :destroy
      has_many :pages, through: :page_blocks

      translates :content, type: :string

      store_attributes :css_settings do
        general_styling_enabled String, default: 'false'
      end
    end
  end
end
