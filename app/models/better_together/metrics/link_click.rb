# frozen_string_literal: true

# app/models/better_together/metrics/link_click.rb
module BetterTogether
  module Metrics
    class LinkClick < ApplicationRecord # rubocop:todo Style/Documentation
      # Validations
      VALID_URL_SCHEMES = %w[http https tel mailto].freeze

      # Regular expression to match http, https, tel, and mailto URLs
      VALID_URL_REGEX = /\A(http|https|tel|mailto):.+\z/

      validates :url, presence: true,
                      format: { with: VALID_URL_REGEX, message: 'must be a valid URL or tel/mailto link' }
      validates :page_url, presence: true, format: URI::DEFAULT_PARSER.make_regexp(%w[http https])
      validates :locale, presence: true, inclusion: { in: I18n.available_locales.map(&:to_s) }
      validates :clicked_at, presence: true
      validates :internal, inclusion: { in: [true, false] }
    end
  end
end
