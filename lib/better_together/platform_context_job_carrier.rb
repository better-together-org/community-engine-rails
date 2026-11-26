# frozen_string_literal: true

module BetterTogether
  # Carries the platform a job was queued on to wherever it runs.
  #
  # Included into ActiveJob::Base (so it also covers mail delivery, Active Storage and
  # third-party jobs). The queuing platform's id is stored in the serialized job and
  # restored as Current.platform around perform, so links, mail and platform-scoped
  # queries resolve to the platform that queued the work and not to the host platform.
  # A job queued with no current platform carries nothing and runs as before.
  module PlatformContextJobCarrier
    extend ActiveSupport::Concern

    SERIALIZED_KEY = 'better_together_platform_id'

    included do
      attr_accessor :carried_platform_id

      around_perform do |job, block|
        job.send(:with_carried_platform, &block)
      end
    end

    def serialize
      super.merge(SERIALIZED_KEY => carried_platform_id || ::Current.platform&.id)
    end

    def deserialize(job_data)
      super
      self.carried_platform_id = job_data[SERIALIZED_KEY]
    end

    private

    def with_carried_platform(&)
      platform = carried_platform_id.present? ? ::BetterTogether::Platform.find_by(id: carried_platform_id) : nil
      return yield unless platform

      ::Current.set(platform:, &)
    end
  end
end
