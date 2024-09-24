# app/models/better_together/metrics/page_view.rb
module BetterTogether
  module Metrics
    class PageView < ApplicationRecord
      belongs_to :pageable, polymorphic: true

      # Validations
      validates :viewed_at, presence: true
      validates :locale, presence: true, inclusion: { in: I18n.available_locales.map(&:to_s) }
    end
  end
end
