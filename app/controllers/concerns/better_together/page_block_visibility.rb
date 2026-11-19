# frozen_string_literal: true

module BetterTogether
  # Assigns the content blocks of a page filtered to what the current viewer may
  # see. Page editors and platform content managers see every block (the view
  # badges the non-public ones); everyone else gets only what
  # Content::BlockPolicy::Scope / #show? permits.
  #
  # Sets @viewer_is_page_editor and @content_blocks (heroes included, in position order).
  module PageBlockVisibility
    extend ActiveSupport::Concern

    private

    def assign_visible_page_content_blocks(page)
      @viewer_is_page_editor = policy(page).update?

      blocks = @viewer_is_page_editor ? page.content_blocks : policy_scope(page.content_blocks)
      @content_blocks = blocks.includes(background_image_file_attachment: :blob).load
    end
  end
end
