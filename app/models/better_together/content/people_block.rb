# frozen_string_literal: true

module BetterTogether
  module Content
    # Renders a collection of BetterTogether::Person records
    class PeopleBlock < Block
      include ::BetterTogether::Content::ResourceBlockAttributes

      def self.content_addable?
        false
      end
    end
  end
end
