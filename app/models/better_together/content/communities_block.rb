# frozen_string_literal: true

module BetterTogether
  module Content
    # Renders a collection of BetterTogether::Community records
    class CommunitiesBlock < Block
      include ::BetterTogether::Content::ResourceBlockAttributes

      def self.content_addable?(actor: nil)
        BetterTogether::FeatureGate.enabled?('content_block_resource_collections', actor:, platform: Current.platform)
      rescue KeyError
        false
      end
    end
  end
end
