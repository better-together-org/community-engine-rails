# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Marks a model as a valid target for BetterTogether::Metrics::Share tracking
    module Shareable
      extend ActiveSupport::Concern

      # Dynamic extension point: a host app opts a model into share tracking solely by
      # including this concern — no gem-owned allow-list to edit. See
      # docs/developers/architecture/polymorphic_allowlist_extension_audit.md
      def self.included_in_models
        Rails.application.eager_load! unless Rails.env.production?
        ActiveRecord::Base.descendants.select do |model|
          model.include?(BetterTogether::Metrics::Shareable)
        end
      end
    end
  end
end
