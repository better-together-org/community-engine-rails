# frozen_string_literal: true

# app/models/better_together/metrics/download.rb
module BetterTogether
  module Metrics
    class Download < ApplicationRecord # rubocop:todo Style/Documentation
      belongs_to :downloadable, polymorphic: true

      validates :file_name, :file_type, :file_size, :downloaded_at, presence: true
      validates :locale, presence: true, inclusion: { in: I18n.available_locales.map(&:to_s) }

      # Additional file validations if necessary
    end
  end
end
