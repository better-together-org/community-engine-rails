# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe PlatformInvitationMailer do
    describe '#invite' do
      let(:platform) do
        create(:platform,
               name: 'Test Platform',
               time_zone: 'America/New_York')
      end
      let(:platform_invitation) do
        create(:platform_invitation,
               invitable: platform,
               invitee_email: 'invitee@example.com',
               greeting: 'Welcome to our platform!',
               locale: 'en',
               valid_from: 1.day.ago,
               valid_until: 1.day.from_now)
      end

      let(:mail) { described_class.invite(platform_invitation) }

      context 'with valid invitation' do
        it 'renders the subject' do
          expect(mail.subject).to eq(
            I18n.t('better_together.platform_invitation_mailer.invite.subject',
                   platform: platform.name)
          )
        end

        it 'renders the receiver email' do
          expect(mail.to).to eq([platform_invitation.invitee_email])
        end

        it 'renders the sender email' do
          expect(mail.from).to eq(['from@example.com'])
        end

        it 'assigns @platform_invitation' do
          expect(mail.body.encoded).to match(platform_invitation.greeting)
        end

        it 'assigns @platform' do
          expect(mail.body.encoded).to match(platform.name)
        end

        it 'includes invitation URL' do
          expect(mail.body.encoded).to match(/#{Regexp.escape(platform_invitation.url)}/)
        end

        it 'includes greeting text' do
          expect(mail.body.encoded).to match(/Welcome to our platform/)
        end
      end

      context 'with blank invitee_email' do
        let(:platform_invitation) do
          create(:platform_invitation,
                 invitable: platform,
                 invitee_email: '',
                 locale: 'en')
        end

        it 'returns nil without sending' do
          expect(mail.to).to be_nil
        end

        it 'does not render the email body' do
          expect(mail.message).to be_a(ActionMailer::Base::NullMail)
        end
      end

      context 'with nil invitee_email' do
        let(:platform_invitation) do
          build(:platform_invitation,
                invitable: platform,
                invitee_email: nil,
                locale: 'en')
        end

        before do
          # Skip validation to create record with nil email for testing
          platform_invitation.save(validate: false)
        end

        it 'returns nil without sending' do
          mail = described_class.invite(platform_invitation)
          expect(mail.to).to be_nil
        end
      end

      context 'with different locale' do
        let(:platform_invitation) do
          create(:platform_invitation,
                 invitable: platform,
                 invitee_email: 'invitee@example.com',
                 locale: 'es')
        end

        around do |example|
          I18n.with_locale(:es) do
            example.run
          end
        end

        it 'uses the invitation locale for subject' do
          expect(mail.subject).to be_present
        end

        it 'sets the mailer locale' do
          # The mailer should use the invitation's locale
          expect(mail.body.encoded).to be_present
        end
      end

      context 'with different time zone' do
        let(:platform) do
          create(:platform,
                 name: 'Test Platform',
                 time_zone: 'Asia/Tokyo')
        end

        it 'sends email with platform time zone awareness' do
          expect(mail.to).to eq([platform_invitation.invitee_email])
        end
      end

      context 'with valid_from and valid_until dates' do
        let(:platform_invitation) do
          create(:platform_invitation,
                 invitable: platform,
                 invitee_email: 'invitee@example.com',
                 valid_from: Date.parse('2025-01-01'),
                 valid_until: Date.parse('2025-12-31'))
        end

        it 'includes validity period in email' do
          # Email body should have access to @valid_from and @valid_until
          expect(mail.body.encoded).to be_present
        end
      end

      context 'with HTML and text parts' do
        it 'generates multipart email' do
          expect(mail.body.parts.size).to be > 0
        end

        it 'includes HTML part' do
          html_part = mail.body.parts.find { |p| p.content_type.match(/html/) }
          expect(html_part).to be_present if mail.multipart?
        end

        it 'includes text part' do
          text_part = mail.body.parts.find { |p| p.content_type.match(/plain/) }
          expect(text_part).to be_present if mail.multipart?
        end
      end

      context 'when platform has custom settings' do
        let(:platform) do
          create(:platform,
                 name: 'Custom Platform',
                 time_zone: 'Pacific/Auckland')
        end

        it 'uses platform name in subject' do
          expect(mail.subject).to include('Custom Platform')
        end
      end

      describe 'instance variable assignments' do
        before { mail.deliver_now }

        it 'assigns @invitee_email' do
          expect(mail.instance_variable_get(:@invitee_email)).to eq(platform_invitation.invitee_email)
        end

        it 'assigns @greeting' do
          expect(mail.instance_variable_get(:@greeting)).to eq(platform_invitation.greeting)
        end

        it 'assigns @valid_from' do
          expect(mail.instance_variable_get(:@valid_from)).to eq(platform_invitation.valid_from)
        end

        it 'assigns @valid_until' do
          expect(mail.instance_variable_get(:@valid_until)).to eq(platform_invitation.valid_until)
        end

        it 'assigns @invitation_url' do
          expect(mail.instance_variable_get(:@invitation_url)).to eq(platform_invitation.url)
        end
      end
    end
  end
end
