# frozen_string_literal: true

module BetterTogether
  module Content
    # Renders a collection of BetterTogether::Person records
    class PeopleBlock < Block
      include ::BetterTogether::Content::ResourceBlockAttributes
    end
  end
end
