# frozen_string_literal: true

module BetterTogether
  module Content
    # Renders raw html from an attribute
    class Html < Block

      has_many :page_blocks, foreign_key: :block_id, dependent: :destroy
      has_many :pages, through: :page_blocks
      
      store_attributes :content_data do
        html_content String, default: ''
      end

      def self.extra_permitted_attributes
        %i[ html_content ]
      end
    end
  end
end
