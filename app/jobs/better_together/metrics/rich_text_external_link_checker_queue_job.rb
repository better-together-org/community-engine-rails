# frozen_string_literal: true

module BetterTogether
  module Metrics
    class RichTextExternalLinkCheckerQueueJob < RichTextLinkCheckerQueueJob
      protected

      def model_collection
        super.where(link_type: 'external')
      end
    end
  end
end
