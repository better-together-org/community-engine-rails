# frozen_string_literal: true

module BetterTogether
  module Content
    # Renders a template from a file
    class Template < Block
      class_attribute :available_templates, default: %w[
        better_together/content/blocks/template/default
        better_together/content/blocks/template/host_community_contact_details
      ]

      has_many :page_blocks, foreign_key: :block_id, dependent: :destroy
      has_many :pages, through: :page_blocks

      store_attributes :content_data do
        template_path String
      end

      validates :template_path, presence: true, inclusion: { in: ->(template) { template.class.available_templates } }
    end
  end
end
