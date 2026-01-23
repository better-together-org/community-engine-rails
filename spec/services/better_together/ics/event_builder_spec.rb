# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Ics
    RSpec.describe EventBuilder do
      let(:person) { create(:person) }
      let(:event) do
        create(:event,
               name: 'Test Event',
               starts_at: Time.zone.parse('2024-03-15 14:00:00 UTC'),
               ends_at: Time.zone.parse('2024-03-15 16:00:00 UTC'),
               timezone: 'America/New_York',
               creator: person)
      end
      let(:builder) { described_class.new(event) }

      describe '#build' do
        it 'includes DTSTAMP' do
          result = builder.build
          expect(result.any? { |line| line.start_with?('DTSTAMP:') }).to be true
        end

        it 'includes UID' do
          result = builder.build
          expect(result).to include("UID:event-#{event.id}@better-together")
        end

        it 'includes SUMMARY with event name' do
          result = builder.build
          expect(result).to include('SUMMARY:Test Event')
        end

        it 'includes DTSTART' do
          result = builder.build
          expect(result.any? { |line| line.start_with?('DTSTART') }).to be true
        end

        it 'includes DTEND when event has end time' do
          result = builder.build
          expect(result.any? { |line| line.start_with?('DTEND') }).to be true
        end

        it 'includes URL when event has url method' do
          allow(event).to receive(:respond_to?).and_call_original
          allow(event).to receive(:respond_to?).with(:url).and_return(true)
          allow(event).to receive(:url).and_return('https://example.com/events/test')
          result = builder.build
          expect(result.any? { |line| line.start_with?('URL:') }).to be true
          expect(result.any? { |line| line.include?('example.com') }).to be true
        end

        context 'with UTC timezone' do
          before { event.update!(timezone: 'UTC') }

          it 'formats times with Z suffix for UTC' do
            result = builder.build
            dtstart_line = result.find { |line| line.start_with?('DTSTART:') }
            expect(dtstart_line).to end_with('Z')
          end
        end

        context 'with non-UTC timezone' do
          it 'includes timezone ID in DTSTART' do
            result = builder.build
            dtstart_line = result.find { |line| line.start_with?('DTSTART;') }
            expect(dtstart_line).to include('TZID=America/New_York')
          end

          it 'formats time without Z suffix for local time' do
            result = builder.build
            dtstart_line = result.find { |line| line.start_with?('DTSTART;') }
            expect(dtstart_line).not_to end_with('Z')
          end
        end

        context 'with description' do
          before do
            event.update!(description: 'This is a test event description')
          end

          it 'includes DESCRIPTION' do
            result = builder.build
            expect(result.any? { |line| line.start_with?('DESCRIPTION:') }).to be true
          end

          it 'sanitizes HTML from description' do
            event.update!(description: '<p>Test <strong>description</strong></p>')
            result = builder.build
            desc_line = result.find { |line| line.start_with?('DESCRIPTION:') }
            expect(desc_line).not_to include('<p>')
            expect(desc_line).not_to include('<strong>')
          end
        end

        context 'without description' do
          before do
            allow(event).to receive(:respond_to?).and_call_original
            allow(event).to receive(:respond_to?).with(:description).and_return(false)
          end

          it 'does not include DESCRIPTION' do
            result = builder.build
            expect(result.any? { |line| line.start_with?('DESCRIPTION:') }).to be false
          end
        end

        context 'without end time' do
          before do
            allow(event).to receive(:ends_at).and_return(nil)
          end

          it 'does not include DTEND' do
            result = builder.build
            expect(result.any? { |line| line.start_with?('DTEND') }).to be false
          end
        end
      end
    end
  end
end
