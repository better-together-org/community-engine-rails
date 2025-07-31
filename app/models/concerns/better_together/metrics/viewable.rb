# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Marks a model as viewable for metrics page view tracking
    module Viewable
      extend ActiveSupport::Concern

      included do
        include ::BetterTogether::Viewable
      end

      def self.included_in_models
        Rails.application.eager_load! if Rails.env.development?
        ActiveRecord::Base.descendants.select do |model|
          model.included_modules.include?(BetterTogether::Metrics::Viewable)
        end
      end
    end
  end
end
