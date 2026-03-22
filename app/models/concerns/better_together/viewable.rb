# frozen_string_literal: true

module BetterTogether
  # Interface to access view data from the pageable record
  module Viewable
    extend ActiveSupport::Concern

    included do
      has_many :views,
               class_name: 'BetterTogether::Metrics::PageView',
               as: :pageable
    end
  end
end
