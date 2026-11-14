# frozen_string_literal: true

module BetterTogether
  module Content
    # Lets a block be embedded in rich text as an Action Text attachment, so a post body holds a real
    # block (kept public and visible by the AttachableRegistry) rather than pasted embed HTML.
    # Opt in per host with ContentSecurity::AttachableRegistry.register; see docs/development/rich_text_block_attachments.md.
    module AttachableBlock
      extend ActiveSupport::Concern

      # Included at module level so the partial path methods below take precedence over Action Text's.
      include ActionText::Attachable

      def to_attachable_partial_path
        "better_together/content/attachments/#{model_name.element}"
      end

      def to_trix_content_attachment_partial_path
        "better_together/content/attachments/#{model_name.element}_trix"
      end
    end
  end
end
