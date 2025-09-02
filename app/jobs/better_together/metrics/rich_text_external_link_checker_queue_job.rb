# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Queues jobs that check external links found inside ActionText rich content.
    # Subclasses of RichTextLinkCheckerQueueJob should implement the specifics
    # for how individual link check jobs are performed.
    class RichTextExternalLinkCheckerQueueJob < RichTextLinkCheckerQueueJob
      protected

      def model_collection
        super.where(link_type: 'external')
      end
    end
  end
end
