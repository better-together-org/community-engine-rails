# frozen_string_literal: true

module BetterTogether
  module Metrics
    class SearchQuery < ApplicationRecord # rubocop:todo Style/Documentation
      include PlatformScoped

      validates :query, presence: true
      validates :results_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
      validates :locale, presence: true, inclusion: { in: I18n.available_locales.map(&:to_s) }
      validates :searched_at, presence: true
      validates :logged_in, inclusion: { in: [true, false] }
    end
  end
end
