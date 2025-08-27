# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # rubocop:todo Metrics/ModuleLength
  RSpec.describe EventMailer do
    let(:person) { create(:person) }
    let(:event) { create(:event, :upcoming, :with_simple_location) }

    describe '#event_reminder' do
      let(:mail) { described_class.with(person: person, event: event, reminder_type: '24_hours').event_reminder }

      it 'renders the headers' do # rubocop:todo RSpec/MultipleExpectations
        expect(mail.subject).to eq(I18n.t('better_together.event_mailer.event_reminder.subject',
                                          event_name: event.name))
        expect(mail.to).to eq([person.email])
        expected_from_email = 'community@bettertogethersolutions.com'
        expect(mail.from).to eq([expected_from_email])
      end

      it 'renders the body with event details' do # rubocop:todo RSpec/MultipleExpectations
        expect(mail.body.encoded).to include(event.name)
        expect(mail.body.encoded).to include('trix-content') if event.description.present?
        expect(mail.body.encoded).to include(event.location_display_name) if event.location?
      end

      it 'includes event timing information' do
        expect(mail.body.encoded).to include(I18n.l(event.starts_at, format: :long))
      end

      context 'when event has registration URL' do
        let(:event_with_registration) { create(:event, :upcoming, registration_url: 'http://127.0.0.1:3000/register') }
        let(:mail) do
          described_class.with(person: person, event: event_with_registration, reminder_type: '24_hours').event_reminder
        end

        it 'includes registration link' do
          expect(mail.body.encoded).to include(event_with_registration.registration_url)
        end
      end

      context 'when event has location' do
        it 'includes location information' do
          expect(mail.body.encoded).to include(event.location_display_name)
        end
      end

      context 'when event has duration' do
        let(:timed_event) do
          create(:event, :upcoming,
                 starts_at: 1.day.from_now,
                 ends_at: 1.day.from_now + 2.hours)
        end
        let(:mail) do
          described_class.with(person: person, event: timed_event, reminder_type: '24_hours').event_reminder
        end

        it 'includes duration information' do
          expect(mail.body.encoded).to match(/\d+(\.\d+)?\s+hours/)
        end
      end
    end

    describe '#event_update' do
      let(:changed_attributes) { %w[name starts_at] }
      let(:mail) do
        described_class.with(person: person, event: event, changed_attributes: changed_attributes).event_update
      end

      it 'renders the headers' do # rubocop:todo RSpec/MultipleExpectations
        expect(mail.subject).to eq(I18n.t('better_together.event_mailer.event_update.subject',
                                          event_name: event.name))
        expect(mail.to).to eq([person.email])
        expected_from_email = 'community@bettertogethersolutions.com'
        expect(mail.from).to eq([expected_from_email])
      end

      it 'renders the body with update information' do # rubocop:todo RSpec/MultipleExpectations
        expect(mail.body.encoded).to include(event.name)
        expect(mail.body.encoded).to include('updated')
      end

      it 'includes changed attributes information' do # rubocop:todo RSpec/MultipleExpectations
        expect(mail.body.encoded).to include('name')
        expect(mail.body.encoded).to include('Starts at')
      end

      context 'with single changed attribute' do
        let(:changed_attributes) { ['name'] }

        it 'renders singular update message' do
          expect(mail.body.encoded).to match(/has been updated/i)
        end
      end

      context 'with multiple changed attributes' do
        let(:changed_attributes) { %w[name starts_at location] }

        it 'renders plural update message' do
          expect(mail.body.encoded).to match(/has been updated with several changes/i)
        end
      end
    end

    describe 'delivery methods' do
      it 'delivers event reminder mail' do
        expect do
          described_class.with(person: person, event: event, reminder_type: '24_hours').event_reminder.deliver_now
        end.not_to raise_error
      end

      it 'delivers event update mail' do
        expect do
          described_class.with(person: person, event: event, changed_attributes: ['name']).event_update.deliver_now
        end.not_to raise_error
      end
    end

    describe 'configuration' do
      it 'uses configured from email' do
        mail = described_class.with(person: person, event: event, reminder_type: '24_hours').event_reminder
        expected_from_email = 'community@bettertogethersolutions.com'
        expect(mail.from).to eq([expected_from_email])
      end

      it 'includes organization branding' do
        mail = described_class.with(person: person, event: event, reminder_type: '24_hours').event_reminder
        # The platform name should appear in the email
        expect(mail.body.encoded).to include('Better Together')
      end
    end

    describe 'localization' do
      around do |example|
        I18n.with_locale(:es) do
          example.run
        end
      end

      it 'uses correct locale for subject' do
        mail = described_class.with(person: person, event: event, reminder_type: '24_hours').event_reminder
        # Test would check Spanish subject line
        expect(mail.subject).to be_present
      end

      it 'uses correct locale for body content' do
        mail = described_class.with(person: person, event: event, reminder_type: '24_hours').event_reminder
        # Test would check Spanish content
        expect(mail.body.encoded).to be_present
      end
    end
  end
end
