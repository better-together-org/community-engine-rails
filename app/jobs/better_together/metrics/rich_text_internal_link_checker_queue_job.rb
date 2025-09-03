# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Queues jobs that check internal links found inside ActionText rich content.
    # This job narrows the collection to internal links and may delay processing
    # to reduce immediate load on the application.
    class RichTextInternalLinkCheckerQueueJob < RichTextLinkCheckerQueueJob
      protected

      def model_collection
        super.where(link_type: 'internal')
      end

      def queue_delay
        5.minutes
      end

      def child_job_class
        BetterTogether::Metrics::InternalLinkCheckerJob
      end
    end
  end
end
