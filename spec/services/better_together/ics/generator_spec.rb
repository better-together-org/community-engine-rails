# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Ics
    RSpec.describe Generator do
      let(:person) { create(:person) }
      let(:event) do
        create(:event,
               name: 'Test Event',
               starts_at: Time.zone.parse('2024-03-15 14:00:00 UTC'),
               ends_at: Time.zone.parse('2024-03-15 16:00:00 UTC'),
               timezone: 'America/New_York',
               creator: person)
      end
      let(:generator) { described_class.new(event) }

      describe '#generate' do
        it 'generates valid ICS content' do
          result = generator.generate
          expect(result).to be_a(String)
          expect(result).not_to be_empty
        end

        it 'includes VCALENDAR header' do
          result = generator.generate
          expect(result).to include('BEGIN:VCALENDAR')
          expect(result).to include('END:VCALENDAR')
        end

        it 'includes VERSION 2.0' do
          result = generator.generate
          expect(result).to include('VERSION:2.0')
        end

        it 'includes PRODID' do
          result = generator.generate
          expect(result).to include('PRODID:-//Better Together Community Engine//EN')
        end

        it 'includes CALSCALE' do
          result = generator.generate
          expect(result).to include('CALSCALE:GREGORIAN')
        end

        it 'includes METHOD:PUBLISH' do
          result = generator.generate
          expect(result).to include('METHOD:PUBLISH')
        end

        it 'includes VEVENT component' do
          result = generator.generate
          expect(result).to include('BEGIN:VEVENT')
          expect(result).to include('END:VEVENT')
        end

        it 'uses CRLF line endings' do
          result = generator.generate
          expect(result).to include("\r\n")
          expect(result).not_to match(/(?<!\r)\n/)
        end

        context 'with non-UTC timezone' do
          it 'includes VTIMEZONE component' do
            result = generator.generate
            expect(result).to include('BEGIN:VTIMEZONE')
            expect(result).to include('END:VTIMEZONE')
          end

          it 'includes timezone ID' do
            result = generator.generate
            expect(result).to include('TZID:America/New_York')
          end

          it 'places VTIMEZONE before VEVENT' do
            result = generator.generate
            vtimezone_pos = result.index('BEGIN:VTIMEZONE')
            vevent_pos = result.index('BEGIN:VEVENT')
            expect(vtimezone_pos).to be < vevent_pos
          end
        end

        context 'with UTC timezone' do
          before { event.update!(timezone: 'UTC') }

          it 'does not include VTIMEZONE component' do
            result = generator.generate
            expect(result).not_to include('BEGIN:VTIMEZONE')
          end
        end

        context 'with event details' do
          it 'includes event name as SUMMARY' do
            result = generator.generate
            expect(result).to include('SUMMARY:Test Event')
          end

          it 'includes DTSTART' do
            result = generator.generate
            expect(result).to match(/DTSTART/)
          end

          it 'includes DTEND' do
            result = generator.generate
            expect(result).to match(/DTEND/)
          end

          it 'includes UID' do
            result = generator.generate
            expect(result).to include("UID:event-#{event.id}@better-together")
          end
        end

        context 'integration with Event model' do
          it 'generates identical output to Event#to_ics' do
            generator_output = generator.generate
            event_output = event.to_ics
            expect(generator_output).to eq(event_output)
          end
        end
      end
    end
  end
end
