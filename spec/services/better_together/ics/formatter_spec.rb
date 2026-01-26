# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Ics # rubocop:disable Metrics/ModuleLength
    RSpec.describe Formatter do
      include ActiveSupport::Testing::TimeHelpers

      describe '.timestamp' do
        it 'returns current time in ICS format (UTC)' do
          travel_to Time.zone.parse('2024-03-15 14:30:00 UTC') do
            timestamp = described_class.timestamp
            expected = Time.current.utc.strftime('%Y%m%dT%H%M%SZ')
            expect(timestamp).to eq(expected)
          end
        end

        it 'ends with Z to indicate UTC' do
          expect(described_class.timestamp).to end_with('Z')
        end

        it 'uses YYYYMMDDTHHMMSSZ format' do
          timestamp = described_class.timestamp
          expect(timestamp).to match(/\A\d{8}T\d{6}Z\z/)
        end
      end

      describe '.utc_time' do
        it 'formats datetime in UTC for ICS' do
          datetime = Time.zone.parse('2024-03-15 14:30:00')
          result = described_class.utc_time(datetime)
          expect(result).to eq(datetime.utc.strftime('%Y%m%dT%H%M%SZ'))
        end

        it 'ends with Z to indicate UTC' do
          datetime = Time.zone.parse('2024-03-15 14:30:00')
          expect(described_class.utc_time(datetime)).to end_with('Z')
        end

        it 'returns nil for nil datetime' do
          expect(described_class.utc_time(nil)).to be_nil
        end

        it 'converts to UTC from other timezones' do
          ny_tz = ActiveSupport::TimeZone['America/New_York']
          datetime = ny_tz.parse('2024-03-15 14:30:00 EDT')
          result = described_class.utc_time(datetime)
          # 14:30 EDT = 18:30 UTC
          expect(result).to include('T183000Z')
        end
      end

      describe '.local_time' do
        it 'formats datetime in local timezone without Z suffix' do
          datetime = Time.zone.parse('2024-03-15 18:30:00 UTC')
          result = described_class.local_time(datetime, 'America/New_York')
          # 18:30 UTC = 14:30 EDT (during DST)
          expect(result).to eq('20240315T143000')
        end

        it 'does not include Z suffix for local times' do
          datetime = Time.current
          result = described_class.local_time(datetime, 'America/New_York')
          expect(result).not_to end_with('Z')
        end

        it 'returns nil for nil datetime' do
          expect(described_class.local_time(nil, 'America/New_York')).to be_nil
        end

        it 'returns nil for nil timezone' do
          datetime = Time.current
          expect(described_class.local_time(datetime, nil)).to be_nil
        end

        it 'returns nil for invalid timezone' do
          datetime = Time.current
          expect(described_class.local_time(datetime, 'Invalid/Timezone')).to be_nil
        end

        it 'handles different timezones correctly' do
          datetime = Time.zone.parse('2024-01-15 12:00:00 UTC')

          ny_result = described_class.local_time(datetime, 'America/New_York')
          expect(ny_result).to eq('20240115T070000') # UTC-5 in winter

          london_result = described_class.local_time(datetime, 'Europe/London')
          expect(london_result).to eq('20240115T120000') # Same as UTC in winter

          tokyo_result = described_class.local_time(datetime, 'Asia/Tokyo')
          expect(tokyo_result).to eq('20240115T210000') # UTC+9
        end
      end

      describe '.utc_offset' do
        it 'formats positive UTC offset' do
          # +5 hours = 18000 seconds
          expect(described_class.utc_offset(18_000)).to eq('+0500')
        end

        it 'formats negative UTC offset' do
          # -5 hours = -18000 seconds
          expect(described_class.utc_offset(-18_000)).to eq('-0500')
        end

        it 'formats zero offset' do
          expect(described_class.utc_offset(0)).to eq('+0000')
        end

        it 'formats offset with minutes' do
          # +5:30 = 19800 seconds
          expect(described_class.utc_offset(19_800)).to eq('+0530')
        end

        it 'formats negative offset with minutes' do
          # -9000 seconds = -2 hours 30 minutes = -0230
          # But Ruby's integer division: -9000 / 3600 = -3 (floor), then 9000 % 3600 = 1800, 1800/60 = 30
          # So result is -0330
          expect(described_class.utc_offset(-9000)).to eq('-0330')
        end

        it 'pads hours and minutes with leading zeros' do
          # +1:05 = 3900 seconds
          expect(described_class.utc_offset(3900)).to eq('+0105')
        end

        it 'handles large positive offsets' do
          # +14 hours (Kiribati) = 50400 seconds
          expect(described_class.utc_offset(50_400)).to eq('+1400')
        end

        it 'handles large negative offsets' do
          # -12 hours (Baker Island) = -43200 seconds
          expect(described_class.utc_offset(-43_200)).to eq('-1200')
        end
      end

      describe '.normalize_line_endings' do
        it 'converts LF to CRLF' do
          content = "line1\nline2\nline3"
          result = described_class.normalize_line_endings(content)
          expect(result).to eq("line1\r\nline2\r\nline3")
        end

        it 'preserves existing CRLF' do
          content = "line1\r\nline2\r\nline3"
          result = described_class.normalize_line_endings(content)
          expect(result).to eq("line1\r\nline2\r\nline3")
        end

        it 'handles mixed line endings' do
          content = "line1\r\nline2\nline3\r\nline4"
          result = described_class.normalize_line_endings(content)
          expect(result).to eq("line1\r\nline2\r\nline3\r\nline4")
        end

        it 'handles empty string' do
          expect(described_class.normalize_line_endings('')).to eq('')
        end

        it 'handles string with no line breaks' do
          content = 'single line'
          expect(described_class.normalize_line_endings(content)).to eq('single line')
        end

        it 'does not double CRLF on already normalized content' do
          content = "line1\r\nline2\r\n"
          result = described_class.normalize_line_endings(content)
          expect(result).not_to include("\r\r\n")
          expect(result).to eq("line1\r\nline2\r\n")
        end
      end
    end
  end
end
