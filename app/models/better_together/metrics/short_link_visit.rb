# frozen_string_literal: true

module BetterTogether
  module Metrics
    class ShortLinkVisit < PlatformRecord # rubocop:todo Style/Documentation
      belongs_to :short_link, class_name: 'BetterTogether::ShortLink'

      validates :visited_at, presence: true
    end
  end
end
