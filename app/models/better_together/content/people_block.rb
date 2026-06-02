# frozen_string_literal: true

module BetterTogether
  module Content
    # Renders a collection of BetterTogether::Person records
    class PeopleBlock < Block
      include ::BetterTogether::Content::ResourceBlockAttributes

      def self.content_addable?(actor: nil)
        BetterTogether::FeatureGate.enabled?('new_content_blocks', actor:, platform: Current.platform)
      rescue KeyError
        false
      end
    end
  end
end
