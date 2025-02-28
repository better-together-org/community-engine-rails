# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Interface to access page view data from the pageable record
    module Pageable
      extend ActiveSupport::Concern

      included do
        has_many :page_views,
                 class_name: 'BetterTogether::Metrics::PageView',
                 as: :pageable
      end
    end
  end
end
