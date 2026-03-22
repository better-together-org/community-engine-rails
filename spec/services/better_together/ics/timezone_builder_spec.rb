# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Ics
    RSpec.describe TimezoneBuilder do
      let(:reference_time) { Time.zone.parse('2024-03-15 14:00:00 UTC') }

      describe '#build' do
        context 'with UTC timezone' do
          let(:builder) { described_class.new('UTC', reference_time) }

          it 'returns empty array for UTC' do
            expect(builder.build).to eq([])
          end
        end

        context 'with Etc/UTC timezone' do
          let(:builder) { described_class.new('Etc/UTC', reference_time) }

          it 'returns empty array for Etc/UTC' do
            expect(builder.build).to eq([])
          end
        end

        context 'with nil timezone' do
          let(:builder) { described_class.new(nil, reference_time) }

          it 'returns empty array' do
            expect(builder.build).to eq([])
          end
        end

        context 'with America/New_York timezone' do
          let(:builder) { described_class.new('America/New_York', reference_time) }

          it 'generates VTIMEZONE component' do
            result = builder.build
            expect(result).to include('BEGIN:VTIMEZONE')
            expect(result).to include('END:VTIMEZONE')
          end

          it 'includes timezone ID' do
            result = builder.build
            expect(result).to include('TZID:America/New_York')
          end

          it 'includes STANDARD component' do
            result = builder.build
            expect(result).to include('BEGIN:STANDARD')
            expect(result).to include('END:STANDARD')
          end

          it 'includes DAYLIGHT component for DST-observing timezone' do
            result = builder.build
            expect(result).to include('BEGIN:DAYLIGHT')
            expect(result).to include('END:DAYLIGHT')
          end

          it 'includes DTSTART' do
            result = builder.build
            standard_section = result.join("\n")
            expect(standard_section).to match(/DTSTART:\d{8}T\d{6}/)
          end

          it 'includes TZOFFSETFROM and TZOFFSETTO' do
            result = builder.build
            combined = result.join("\n")
            expect(combined).to include('TZOFFSETFROM:')
            expect(combined).to include('TZOFFSETTO:')
          end
        end

        context 'with non-DST timezone' do
          let(:builder) { described_class.new('Asia/Tokyo', reference_time) }

          it 'only includes STANDARD component' do
            result = builder.build
            expect(result).to include('BEGIN:STANDARD')
            expect(result).not_to include('BEGIN:DAYLIGHT')
          end
        end

        context 'with Europe/London timezone' do
          let(:summer_time) { Time.zone.parse('2024-07-15 12:00:00 UTC') }
          let(:builder) { described_class.new('Europe/London', summer_time) }

          it 'includes both STANDARD and DAYLIGHT for DST-observing timezone' do
            result = builder.build
            expect(result).to include('BEGIN:STANDARD')
            expect(result).to include('BEGIN:DAYLIGHT')
          end
        end

        context 'with invalid timezone' do
          let(:builder) { described_class.new('Invalid/Timezone', reference_time) }

          it 'returns empty array' do
            expect(builder.build).to eq([])
          end
        end

        context 'with timezone that has half-hour offset' do
          let(:builder) { described_class.new('Asia/Kolkata', reference_time) }

          it 'generates VTIMEZONE component' do
            result = builder.build
            expect(result).to include('BEGIN:VTIMEZONE')
            expect(result).to include('TZID:Asia/Kolkata')
          end

          it 'formats offset correctly' do
            result = builder.build
            combined = result.join("\n")
            expect(combined).to match(/TZOFFSETTO:\+\d{4}/)
          end
        end
      end
    end
  end
end
