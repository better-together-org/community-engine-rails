# frozen_string_literal: true

# app/models/better_together/metrics/download.rb
module BetterTogether
  module Metrics
    class Download < ApplicationRecord # rubocop:todo Style/Documentation
      # Explicit, fully-qualified include rather than inheriting from PlatformRecord —
      # bare `include PlatformScoped` here would resolve to the generic top-level
      # concern (Current.platform/host only) instead of this module's
      # parent-aware derivation, because PlatformRecord's own lexical nesting
      # doesn't include BetterTogether::Metrics.
      include BetterTogether::Metrics::PlatformScoped

      belongs_to :downloadable, polymorphic: true

      validates :file_name, :file_type, :file_size, :downloaded_at, presence: true
      validates :locale, presence: true, inclusion: { in: I18n.available_locales.map(&:to_s) }
      validates :logged_in, inclusion: { in: [true, false] }

      # Additional file validations if necessary
    end
  end
end
