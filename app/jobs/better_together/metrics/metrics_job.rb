module BetterTogether
  class Metrics::MetricsJob < ApplicationJob
    queue_as :metrics
  end
end
