# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module CalendarExport
    RSpec.describe GoogleCalendarJson do
      let(:creator) { create(:better_together_person) }
      let(:event) do
        create(:better_together_event,
               name: 'Test Event',
               description: 'Test Description',
               starts_at: Time.zone.parse('2026-02-15 14:00:00'),
               ends_at: Time.zone.parse('2026-02-15 16:00:00'),
               timezone: 'America/Chicago',
               creator:)
      end

      describe '#generate' do
        subject(:json_output) { described_class.new(event).generate }
        let(:parsed_json) { JSON.parse(json_output) }

        it 'generates valid JSON' do
          expect { parsed_json }.not_to raise_error
        end

        it 'includes calendar metadata' do
          expect(parsed_json['kind']).to eq('calendar#events')
          expect(parsed_json['summary']).to eq('Better Together Events')
        end

        it 'includes items array' do
          expect(parsed_json['items']).to be_an(Array)
          expect(parsed_json['items'].length).to eq(1)
        end

        describe 'event JSON structure' do
          let(:event_json) { parsed_json['items'].first }

          it 'includes Google Calendar event kind' do
            expect(event_json['kind']).to eq('calendar#event')
          end

          it 'includes event id' do
            expect(event_json['id']).to eq(event.id)
          end

          it 'maps name to summary' do
            expect(event_json['summary']).to eq('Test Event')
          end

          it 'converts description to plain text' do
            expect(event_json['description']).to eq('Test Description')
          end

          it 'includes start datetime with timezone' do
            expect(event_json['start']).to be_a(Hash)
            expect(event_json['start']['dateTime']).to be_present
            expect(event_json['start']['timeZone']).to eq('America/Chicago')
          end

          it 'includes end datetime with timezone' do
            expect(event_json['end']).to be_a(Hash)
            expect(event_json['end']['dateTime']).to be_present
            expect(event_json['end']['timeZone']).to eq('America/Chicago')
          end

          it 'includes creator information' do
            expect(event_json['creator']).to be_a(Hash)
            expect(event_json['creator']['email']).to eq(creator.email)
            expect(event_json['creator']['displayName']).to eq(creator.name)
          end
        end

        context 'with multiple events' do
          let(:event2) do
            create(:better_together_event,
                   name: 'Second Event',
                   starts_at: 1.week.from_now,
                   ends_at: 1.week.from_now + 2.hours,
                   creator:)
          end

          it 'includes all events in items array' do
            json_output = described_class.new([event, event2]).generate
            parsed = JSON.parse(json_output)

            expect(parsed['items'].length).to eq(2)
            expect(parsed['items'].map { |e| e['summary'] }).to contain_exactly('Test Event', 'Second Event')
          end
        end

        context 'with missing optional fields' do
          let(:minimal_event) do
            create(:better_together_event,
                   name: 'Minimal Event',
                   starts_at: 1.day.from_now,
                   ends_at: 1.day.from_now + 1.hour,
                   description: nil,
                   creator: nil)
          end

          it 'handles nil description' do
            json_output = described_class.new(minimal_event).generate
            parsed = JSON.parse(json_output)
            event_json = parsed['items'].first

            expect(event_json['description']).to be_nil
          end

          it 'handles nil creator' do
            json_output = described_class.new(minimal_event).generate
            parsed = JSON.parse(json_output)
            event_json = parsed['items'].first

            expect(event_json['creator']).to be_nil
          end
        end
      end
    end
  end
end
