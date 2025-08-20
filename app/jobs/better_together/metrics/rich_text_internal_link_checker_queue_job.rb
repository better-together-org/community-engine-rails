module BetterTogether
  module Metrics
    class RichTextInternalLinkCheckerQueueJob < RichTextLinkCheckerQueueJob
      protected

      def model_collection
        super.where(link_type: 'internal')
      end

      def queue_delay
        5.minutes
      end
    end
  end
end
