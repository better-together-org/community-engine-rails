# frozen_string_literal: true

module BetterTogether
  module Weather
    # A settlement tracked through one weather source. external_ref is the
    # source's own place code (for Environment Canada, "NL/s0000221").
    class Location < ApplicationRecord
      ERROR_LIMIT = 2000

      belongs_to :settlement, class_name: 'BetterTogether::Geography::Settlement'
      belongs_to :source, class_name: 'BetterTogether::Weather::Source'

      has_one :current_condition, class_name: 'BetterTogether::Weather::CurrentCondition',
                                  dependent: :destroy, inverse_of: :location
      has_many :forecasts, class_name: 'BetterTogether::Weather::Forecast',
                           dependent: :destroy, inverse_of: :location
      has_many :observations, class_name: 'BetterTogether::Weather::Observation',
                              dependent: :destroy, inverse_of: :location

      validates :external_ref, presence: true
      validates :settlement_id, uniqueness: { scope: :source_id }
      validates :time_zone, inclusion: { in: ->(_) { TZInfo::Timezone.all_identifiers } }

      scope :enabled, -> { where(enabled: true) }

      after_create_commit :schedule_initial_load

      def adapter
        source.adapter
      end

      def latitude
        self[:latitude] || settlement&.latitude
      end

      def longitude
        self[:longitude] || settlement&.longitude
      end

      def record_success!(**stamps)
        update!(stamps.merge(last_error: nil, last_error_at: nil))
      end

      def record_error!(error)
        update!(last_error: "#{error.class}: #{error.message}".truncate(ERROR_LIMIT), last_error_at: Time.current)
      end

      private

      def schedule_initial_load
        return unless enabled?

        RefreshLocationJob.perform_later(id)
        BackfillLocationJob.perform_later(id)
      end
    end
  end
end
