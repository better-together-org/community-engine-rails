# frozen_string_literal: true

module BetterTogether
  module Metrics
    class MetricsJob < ApplicationJob # rubocop:todo Style/Documentation
      queue_as :metrics
    end
  end
end
