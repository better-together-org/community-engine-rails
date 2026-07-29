# frozen_string_literal: true

module BetterTogether
  module C3
    # ExchangeRate defines the C3 token rate per unit for each contribution type.
    # Authoritative rates are seeded from borgberry.json c3.exchange_rates or this table.
    class ExchangeRate < ApplicationRecord
      self.table_name = 'better_together_c3_exchange_rates'

      CONTRIBUTION_TYPES = {
        compute_cpu: 0,
        compute_gpu: 1,
        compute_metal: 2,
        volunteer: 3,
        code_review: 4,
        documentation: 5,
        moderation: 6,
        embedding: 7,
        transcription: 8,
        inference: 9,
        video_encode: 10,
        shell_task: 11
      }.freeze

      enum :contribution_type, CONTRIBUTION_TYPES

      validates :contribution_type, :rate, :unit_name, :unit_label, presence: true
      validates :rate, numericality: { greater_than: 0 }

      scope :active, -> { where(active: true) }

      # Seed default rates from borgberry C3_RATES definition.
      DEFAULT_RATES = [
        { contribution_type_name: 'compute_cpu', rate: 10.0, unit_name: 'cpu_hour', unit_label: 'CPU hour' },
        { contribution_type_name: 'compute_gpu', rate: 100.0, unit_name: 'gpu_hour', unit_label: 'GPU hour (RTX 2070)' },
        { contribution_type_name: 'compute_metal', rate: 60.0, unit_name: 'metal_hour', unit_label: 'Metal GPU hour (M1)' },
        { contribution_type_name: 'volunteer', rate: 50.0, unit_name: 'hour', unit_label: 'volunteer hour' },
        { contribution_type_name: 'code_review', rate: 20.0, unit_name: 'review', unit_label: 'PR reviewed' },
        { contribution_type_name: 'documentation', rate: 15.0, unit_name: 'pr', unit_label: 'docs PR merged' },
        { contribution_type_name: 'moderation', rate: 5.0, unit_name: 'action', unit_label: 'moderation action' },
        { contribution_type_name: 'embedding', rate: 0.001, unit_name: 'vector', unit_label: 'vector embedded' },
        { contribution_type_name: 'transcription', rate: 2.0, unit_name: 'video_minute', unit_label: 'video minute transcribed' },
        { contribution_type_name: 'inference', rate: 50.0, unit_name: 'gpu_hour', unit_label: 'GPU inference hour' },
        { contribution_type_name: 'video_encode', rate: 60.0, unit_name: 'gpu_hour', unit_label: 'GPU encode hour' },
        { contribution_type_name: 'shell_task', rate: 5.0, unit_name: 'cpu_hour', unit_label: 'shell task CPU hour' }
      ].freeze

      def to_s
        "#{contribution_type_name}: #{rate} C3/#{unit_name}"
      end
    end
  end
end
