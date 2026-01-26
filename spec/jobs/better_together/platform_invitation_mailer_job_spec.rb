# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/ModuleLength
module BetterTogether
  RSpec.describe PlatformInvitationMailerJob do
    include ActiveSupport::Testing::TimeHelpers

    describe '#perform' do
      let(:platform) do
        create(:platform,
               name: 'Test Platform',
               time_zone: 'America/New_York')
      end
      let(:platform_invitation) do
        create(:platform_invitation,
               invitable: platform,
               invitee_email: 'invitee@example.com',
               greeting: 'Welcome!',
               locale: 'en',
               valid_from: 1.day.ago,
               valid_until: 1.day.from_now)
      end

      context 'when invitation is within valid period' do
        it 'sends the invitation email' do
          expect do
            described_class.new.perform(platform_invitation.id)
          end.to change { ActionMailer::Base.deliveries.count }.by(1)

          mail = ActionMailer::Base.deliveries.last
          expect(mail.to).to include(platform_invitation.invitee_email)
        end

        it 'updates last_sent timestamp' do
          freeze_time do
            described_class.new.perform(platform_invitation.id)
            platform_invitation.reload
            expect(platform_invitation.last_sent).to be_within(1.second).of(Time.current)
          end
        end

        it 'uses platform time zone for time comparisons' do
          allow(Time).to receive(:use_zone).and_call_original
          expect(Time).to receive(:use_zone).with(platform.time_zone)
          described_class.new.perform(platform_invitation.id)
        end

        it 'uses invitation locale for email' do
          allow(I18n).to receive(:with_locale).and_call_original
          expect(I18n).to receive(:with_locale).with(platform_invitation.locale.to_sym)
          described_class.new.perform(platform_invitation.id)
        end
      end

      context 'when invitation is before valid_from date' do
        let(:platform_invitation) do
          create(:platform_invitation,
                 invitable: platform,
                 invitee_email: 'invitee@example.com',
                 locale: 'en',
                 valid_from: 1.day.from_now,
                 valid_until: 2.days.from_now)
        end

        it 'does not send the email' do
          expect do
            described_class.new.perform(platform_invitation.id)
          end.not_to have_enqueued_mail(PlatformInvitationMailer, :invite)
        end

        it 'does not update last_sent timestamp' do
          original_last_sent = platform_invitation.last_sent
          described_class.new.perform(platform_invitation.id)
          platform_invitation.reload
          expect(platform_invitation.last_sent).to eq(original_last_sent)
        end

        it 'logs info message' do
          allow(Rails.logger).to receive(:info)
          described_class.new.perform(platform_invitation.id)
          expect(Rails.logger).to have_received(:info)
            .with(/Invitation .* is not within the valid period/)
        end
      end

      context 'when invitation is after valid_until date' do
        let(:platform_invitation) do
          create(:platform_invitation,
                 invitable: platform,
                 invitee_email: 'invitee@example.com',
                 locale: 'en',
                 valid_from: 3.days.ago,
                 valid_until: 1.day.ago)
        end

        it 'does not send the email' do
          expect do
            described_class.new.perform(platform_invitation.id)
          end.not_to have_enqueued_mail(PlatformInvitationMailer, :invite)
        end

        it 'does not update last_sent timestamp' do
          original_last_sent = platform_invitation.last_sent
          described_class.new.perform(platform_invitation.id)
          platform_invitation.reload
          expect(platform_invitation.last_sent).to eq(original_last_sent)
        end
      end

      context 'when valid_until is nil (no expiration)' do
        let(:platform_invitation) do
          create(:platform_invitation,
                 invitable: platform,
                 invitee_email: 'invitee@example.com',
                 locale: 'en',
                 valid_from: 1.day.ago,
                 valid_until: nil)
        end

        it 'sends the email' do
          expect do
            described_class.new.perform(platform_invitation.id)
          end.to change { ActionMailer::Base.deliveries.count }.by(1)
        end

        it 'updates last_sent timestamp' do
          freeze_time do
            described_class.new.perform(platform_invitation.id)
            platform_invitation.reload
            expect(platform_invitation.last_sent).to be_within(1.second).of(Time.current)
          end
        end
      end

      context 'with different time zones' do
        let(:tokyo_platform) do
          create(:platform,
                 name: 'Tokyo Platform',
                 time_zone: 'Asia/Tokyo')
        end
        let(:tokyo_invitation) do
          create(:platform_invitation,
                 invitable: tokyo_platform,
                 invitee_email: 'tokyo@example.com',
                 locale: 'en',
                 valid_from: 1.day.ago,
                 valid_until: 1.day.from_now)
        end

        it 'respects platform time zone' do
          allow(Time).to receive(:use_zone).and_call_original
          expect(Time).to receive(:use_zone).with('Asia/Tokyo')
          described_class.new.perform(tokyo_invitation.id)
        end

        it 'sets last_sent in platform time zone' do
          freeze_time do
            described_class.new.perform(tokyo_invitation.id)
            tokyo_invitation.reload
            expect(tokyo_invitation.last_sent).to be_present
          end
        end
      end

      context 'with different locales' do
        let(:spanish_invitation) do
          create(:platform_invitation,
                 invitable: platform,
                 invitee_email: 'spanish@example.com',
                 locale: 'es',
                 valid_from: 1.day.ago,
                 valid_until: 1.day.from_now)
        end

        it 'uses invitation locale' do
          allow(I18n).to receive(:with_locale).and_call_original
          expect(I18n).to receive(:with_locale).with(:es)
          described_class.new.perform(spanish_invitation.id)
        end
      end

      describe 'retry behavior' do
        it 'retries on Net::OpenTimeout' do
          allow(BetterTogether::PlatformInvitationMailer).to receive(:invite)
            .and_raise(Net::OpenTimeout)

          # Attempting to perform should raise the error (which ActiveJob will then retry)
          expect do
            described_class.new.perform(platform_invitation.id)
          end.to raise_error(Net::OpenTimeout)
        end
      end

      context 'when platform invitation not found' do
        it 'raises ActiveRecord::RecordNotFound' do
          expect do
            described_class.new.perform('nonexistent-id')
          end.to raise_error(ActiveRecord::RecordNotFound)
        end
      end

      describe 'time zone edge cases' do
        it 'handles timezone boundaries correctly' do
          # Create invitation that is valid at current time in platform timezone
          # but might not be in UTC
          Time.use_zone(platform.time_zone) do
            current_time = Time.zone.now
            invitation = create(:platform_invitation,
                                invitable: platform,
                                invitee_email: 'edge@example.com',
                                locale: 'en',
                                valid_from: current_time - 1.hour,
                                valid_until: current_time + 1.hour)

            expect do
              described_class.new.perform(invitation.id)
            end.to change { ActionMailer::Base.deliveries.count }.by(1)
          end
        end
      end

      describe 'job queue' do
        it 'uses mailer queue' do
          expect(described_class.new.queue_name).to eq('mailers')
        end
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength
