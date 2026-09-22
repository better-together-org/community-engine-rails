# frozen_string_literal: true

module BetterTogether
  module Content
    # Renders a collection of BetterTogether::Community records
    class CommunitiesBlock < Block
      include ::BetterTogether::Content::ResourceBlockAttributes
    end
  end
end
