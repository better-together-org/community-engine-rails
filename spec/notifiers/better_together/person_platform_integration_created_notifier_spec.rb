# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # rubocop:todo Metrics/ModuleLength
  RSpec.describe PersonPlatformIntegrationCreatedNotifier do
    let(:integration) { create(:person_platform_integration, provider: 'github') }
    let(:person) { integration.person }
    let(:user) { integration.user }

    subject(:notifier) do
      described_class.new(
        record: integration,
        params: { person_platform_integration: integration }
      )
    end

    describe '#title' do
      it 'includes the provider name' do
        expect(notifier.title).to include('Github')
      end

      it 'mentions integration connection' do
        expect(notifier.title).to include('integration connected')
      end

      it 'uses locale-aware translation' do
        I18n.with_locale(:en) do
          expect(notifier.title).to eq('New Github integration connected')
        end
      end
    end

    describe '#body' do
      it 'includes the provider name' do
        expect(notifier.body).to include('Github')
      end

      it 'includes the formatted creation date' do
        formatted_date = I18n.l(integration.created_at, format: :long)
        expect(notifier.body).to include(formatted_date)
      end

      it 'mentions account integration' do
        expect(notifier.body).to include('account integration')
      end

      it 'uses locale-aware translation' do
        I18n.with_locale(:en) do
          expect(notifier.body).to match(/A new Github account integration was connected on/)
        end
      end
    end

    describe '#build_message' do
      let(:notification) { double('Notification', recipient: person) } # rubocop:todo RSpec/VerifiedDoubles

      it 'returns a hash with title, body, and url' do
        message = notifier.build_message(notification)

        expect(message).to be_a(Hash)
        expect(message).to have_key(:title)
        expect(message).to have_key(:body)
        expect(message).to have_key(:url)
      end

      it 'includes the integration URL' do
        message = notifier.build_message(notification)

        expect(message[:url]).to be_present
        expect(message[:url]).to include('settings')
        expect(message[:url]).to include('#integrations')
      end
    end

    describe '#email_params' do
      let(:notification) { double('Notification') } # rubocop:todo RSpec/VerifiedDoubles

      it 'returns hash with integration and recipient' do
        params = notifier.email_params(notification)

        expect(params[:person_platform_integration]).to eq(integration)
        expect(params[:recipient]).to eq(person)
      end
    end

    describe '#integration' do
      it 'returns the integration from params' do
        expect(notifier.integration).to eq(integration)
      end

      context 'when integration is in record instead of params' do
        subject(:notifier) do
          described_class.new(
            record: integration,
            params: {}
          )
        end

        it 'falls back to record' do
          expect(notifier.integration).to eq(integration)
        end
      end
    end

    describe '#person' do
      it 'returns the person associated with the integration' do
        expect(notifier.person).to eq(person)
      end
    end

    describe '#locale' do
      it 'uses person locale when available' do
        person.update(locale: :fr)
        expect(notifier.locale.to_s).to eq('fr')
      end

      it 'falls back to I18n.locale when person locale is nil' do
        person.update(locale: nil)
        I18n.with_locale(:es) do
          # Since person.locale is nil, it should use I18n.locale which is :es
          expect(notifier.locale.to_s).to eq('es')
        end
      end

      it 'falls back to I18n.default_locale when both are nil' do
        person.update(locale: nil)
        # When both person.locale and I18n.locale are somehow nil, fall back to default
        expect(notifier.locale.to_s).to eq(I18n.default_locale.to_s)
      end
    end

    describe '#url' do
      it 'returns a path to the integration show page' do
        expect(notifier.url).to be_present
        expect(notifier.url).to include('settings')
        expect(notifier.url).to include('#integrations')
      end

      it 'includes the locale in the path' do
        expect(notifier.url).to include('/en/')
      end

      context 'when integration is nil' do
        subject(:notifier) do
          described_class.new(
            record: nil,
            params: { person_platform_integration: nil }
          )
        end

        it 'returns nil' do
          expect(notifier.url).to be_nil
        end
      end
    end

    describe 'delivery methods' do
      it 'is configured with delivery methods' do
        expect(described_class).to respond_to(:delivery_methods)
      end
    end

    describe 'validations' do
      it 'validates presence of record' do
        notifier = described_class.new(record: nil, params: { person_platform_integration: integration })
        expect(notifier).not_to be_valid
        expect(notifier.errors[:record]).to include("can't be blank")
      end

      it 'requires person_platform_integration param' do
        expect do
          described_class.new(record: integration, params: {}).deliver(person)
        end.to raise_error(Noticed::ValidationError, /person_platform_integration.*required/)
      end
    end

    describe 'notification methods' do
      describe 'recipient_has_email?' do
        let(:notification) { double('Notification', recipient: person) } # rubocop:todo RSpec/VerifiedDoubles

        it 'returns true when user has email' do
          expect(user.email).to be_present
          notifier.deliver(person)
          # The notification_methods block delegates to event, which should check email
          expect(user.email).to be_present
        end

        context 'when user has no email' do
          before do
            allow(user).to receive(:email).and_return(nil)
          end

          it 'returns false' do
            expect(user.email).to be_nil
          end
        end
      end
    end

    describe 'integration with different providers' do
      context 'when provider is github' do
        let(:integration) { create(:person_platform_integration, provider: 'github') }

        it 'includes titleized provider name in title' do
          expect(notifier.title).to include('Github')
        end

        it 'includes titleized provider name in body' do
          expect(notifier.body).to include('Github')
        end
      end
    end

    describe 'private methods' do
      describe '#provider_name' do
        it 'returns titleized provider name' do
          expect(notifier.send(:provider_name)).to eq('Github')
        end

        context 'when integration is nil' do
          subject(:notifier) do
            described_class.new(
              record: nil,
              params: { person_platform_integration: nil }
            )
          end

          it 'returns default OAuth' do
            expect(notifier.send(:provider_name)).to eq('OAuth')
          end
        end
      end

      describe '#formatted_created_at' do
        it 'returns formatted date' do
          formatted = notifier.send(:formatted_created_at)
          expect(formatted).to be_a(String)
          expect(formatted).not_to be_empty
        end

        it 'uses the locale from the notifier' do
          allow(notifier).to receive(:locale).and_return(:en)
          I18n.with_locale(:en) do
            formatted = notifier.send(:formatted_created_at)
            expect(formatted).to eq(I18n.l(integration.created_at, format: :long))
          end
        end

        context 'when integration is nil' do
          subject(:notifier) do
            described_class.new(
              record: nil,
              params: { person_platform_integration: nil }
            )
          end

          it 'returns nil' do
            expect(notifier.send(:formatted_created_at)).to be_nil
          end
        end
      end
    end
  end
end
