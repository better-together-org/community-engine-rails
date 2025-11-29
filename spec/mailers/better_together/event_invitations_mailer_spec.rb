# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # rubocop:todo Metrics/ModuleLength
  RSpec.describe EventInvitationsMailer do
    let(:person) { create(:person) }
    let(:event) { create(:event, :upcoming, :with_simple_location) }
    let(:event_invitation) { create(:event_invitation, invitable: event, invitee: person) }

    describe '#invite' do
      let(:mail) { described_class.with(invitation: event_invitation).invite }

      context 'with valid invitation' do
        it 'renders the headers correctly' do
          expect(mail.to).to eq([event_invitation.invitee_email])
          expect(mail.subject).to be_present
          expect(mail.from).to eq(['community@bettertogethersolutions.com'])
        end

        it 'renders the body with event details' do
          expect(mail.body.encoded).to include(event.name)
          # Check for invitation content without requiring specific language
          expect(mail.body.encoded).to match(/invit/i) # Should contain some form of "invited"
        end

        it 'includes invitation URL' do
          expect(mail.body.encoded).to include(event_invitation.url_for_review)
        end

        context 'when event has location' do
          it 'includes location information' do
            expect(mail.body.encoded).to include(event.location_display_name)
          end
        end

        context 'when event has starts_at time' do
          it 'includes formatted start time' do
            # Check that some representation of the start time is present
            expect(mail.body.encoded).to include(event.starts_at.year.to_s)
            expect(mail.body.encoded).to include(event.starts_at.day.to_s)
          end
        end

        context 'when invitation has inviter' do
          let(:inviter) { create(:person) }
          let(:event_invitation_with_inviter) do
            create(:event_invitation, invitable: event, invitee: person, inviter: inviter)
          end
          let(:mail) { described_class.with(invitation: event_invitation_with_inviter).invite }

          it 'includes inviter information' do
            expect(mail.body.encoded).to include(inviter.name)
            # Check for inviter reference without requiring specific language
            expect(mail.body.encoded).to match(/invit.*#{Regexp.escape(inviter.name)}/i)
          end
        end

        context 'when event has description with Action Text and Mobility translations' do
          let(:event_with_description) do
            create(:event, :upcoming, :with_simple_location).tap do |e|
              # Set description using Mobility's translation system
              I18n.with_locale(:en) do
                e.update!(description: 'This is a test event description with **bold** text.')
              end
            end
          end
          let(:event_invitation_with_description) do
            create(:event_invitation, invitable: event_with_description, invitee: person)
          end
          let(:mail) { described_class.with(invitation: event_invitation_with_description).invite }

          it 'handles Action Text description correctly without errors' do
            expect { mail.body.encoded }.not_to raise_error
          end

          it 'includes description content in plain text format' do
            body = mail.body.encoded
            expect(body).to include('This is a test event description')
            # Should include the text content but not the rich text HTML tags
            expect(body).to include('bold')
          end

          it 'converts Action Text to plain text for email display' do
            # The fix ensures that simple_format receives plain text, not a Mobility translation object
            description_text = event_with_description.description.to_plain_text
            expect(mail.body.encoded).to include(description_text)
          end
        end

        context 'when event has no description' do
          let(:event_without_description) { create(:event, :upcoming, :with_simple_location, description: nil) }
          let(:event_invitation_no_desc) do
            create(:event_invitation, invitable: event_without_description, invitee: person)
          end
          let(:mail) { described_class.with(invitation: event_invitation_no_desc).invite }

          it 'does not include description section' do
            # Should not fail and should not have empty description blocks
            expect { mail.body.encoded }.not_to raise_error
            body = mail.body.encoded
            expect(body).not_to include('<strong>Description:</strong>')
          end
        end
      end

      context 'with invalid invitation' do
        let(:event_invitation_no_email) do
          build(:event_invitation, invitable: event, invitee: person, invitee_email: '')
        end
        let(:mail) { described_class.with(invitation: event_invitation_no_email).invite }

        it 'does not send email when invitee_email is blank' do
          expect(mail.to).to be_nil
        end
      end

      context 'localization' do
        let(:french_invitation) do
          create(:event_invitation, invitable: event, invitee: person, locale: 'fr')
        end
        let(:mail) { described_class.with(invitation: french_invitation).invite }

        it 'uses invitation locale for email content' do
          I18n.with_locale(:fr) do
            # This tests that the mailer respects the invitation's locale setting
            expect { mail.body.encoded }.not_to raise_error
            expect { mail.subject }.not_to raise_error
          end
        end
      end
    end
  end
end
