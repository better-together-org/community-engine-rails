# frozen_string_literal: true

module BetterTogether
  module Metrics
    class MetricsJob < ApplicationJob
      queue_as :metrics
    end
  end
end
