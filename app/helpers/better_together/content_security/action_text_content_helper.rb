# frozen_string_literal: true

module BetterTogether
  module ContentSecurity
    # Filters unsafe Action Text attachments before the stock renderer expands them.
    module ActionTextContentHelper
      def render_action_text_attachments(content)
        filtered_content = BetterTogether::ContentSecurity::RichTextAttachmentFilter.new(content).call
        super(filtered_content)
      end
    end
  end
end
