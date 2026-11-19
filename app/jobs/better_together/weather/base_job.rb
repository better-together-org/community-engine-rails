# frozen_string_literal: true

module BetterTogether
  module Weather
    # Base for weather jobs. Nothing is queued, and queued jobs return at once, while
    # weather is off or has no configured source (see Weather.enabled?).
    class BaseJob < ApplicationJob
      queue_as :weather

      before_enqueue { throw :abort unless self.class.work_available? }

      around_perform do |job, block|
        if job.class.work_available?
          block.call
        else
          Rails.logger.debug { "[Weather] #{job.class.name} skipped: weather has no configured source" }
        end
      end

      def self.work_available?
        Weather.enabled?
      end
    end
  end
end
