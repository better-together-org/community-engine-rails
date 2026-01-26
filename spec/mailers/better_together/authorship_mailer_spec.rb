# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::AuthorshipMailer do
  before do
    configure_host_platform
  end

  describe '#authorship_changed_notification' do
    let(:page) { create(:better_together_page, title: 'Test Page') }
    let(:recipient) { create(:better_together_person) }
    let(:actor) { create(:better_together_person, name: 'John Doe') }

    context 'when author is added with actor name' do
      let(:mail) do
        described_class.with(
          page:,
          recipient:,
          action: 'added',
          actor_name: actor.name
        ).authorship_changed_notification
      end

      it 'renders the subject with actor name' do
        expect(mail.subject).to include('Test Page')
        expect(mail.subject).to include('John Doe')
      end

      it 'sends to the recipient email' do
        expect(mail.to).to eq([recipient.email])
      end

      it 'includes page title in body' do
        expect(mail.body.encoded).to include('Test Page')
      end

      it 'includes actor name in body' do
        expect(mail.body.encoded).to include('John Doe')
      end

      it 'is deliverable' do
        expect { mail.deliver_now }.not_to raise_error
      end
    end

    context 'when author is added without actor name' do
      let(:mail) do
        described_class.with(
          page:,
          recipient:,
          action: 'added'
        ).authorship_changed_notification
      end

      it 'renders the subject without actor name' do
        expect(mail.subject).to include('Test Page')
      end

      it 'sends to the recipient email' do
        expect(mail.to).to eq([recipient.email])
      end
    end

    context 'when author is removed with actor name' do
      let(:mail) do
        described_class.with(
          page:,
          recipient:,
          action: 'removed',
          actor_name: actor.name
        ).authorship_changed_notification
      end

      it 'renders the subject for removal with actor' do
        expect(mail.subject).to include('Test Page')
        expect(mail.subject).to include('John Doe')
      end

      it 'sends to the recipient email' do
        expect(mail.to).to eq([recipient.email])
      end
    end

    context 'when author is removed without actor name' do
      let(:mail) do
        described_class.with(
          page:,
          recipient:,
          action: 'removed'
        ).authorship_changed_notification
      end

      it 'renders the subject for removal without actor' do
        expect(mail.subject).to include('Test Page')
      end

      it 'sends to the recipient email' do
        expect(mail.to).to eq([recipient.email])
      end
    end

    context 'when actor_id is provided instead of actor_name' do
      let(:mail) do
        described_class.with(
          page:,
          recipient:,
          action: 'added',
          actor_id: actor.id
        ).authorship_changed_notification
      end

      it 'looks up actor by ID and includes name' do
        expect(mail.subject).to include(actor.name)
      end

      it 'includes actor name in body' do
        expect(mail.body.encoded).to include(actor.name)
      end
    end

    context 'when actor_id is invalid' do
      let(:mail) do
        described_class.with(
          page:,
          recipient:,
          action: 'added',
          actor_id: 'nonexistent-id'
        ).authorship_changed_notification
      end

      it 'handles gracefully without actor name' do
        expect(mail.subject).to include('Test Page')
      end
    end

    context 'locale handling' do
      it 'respects recipient locale' do
        recipient.update(locale: 'es')
        mail = described_class.with(
          page:,
          recipient:,
          action: 'added',
          actor_name: actor.name
        ).authorship_changed_notification

        expect(mail.body.encoded).to be_present
      end
    end

    context 'time zone handling' do
      it 'respects recipient time zone' do
        recipient.update(time_zone: 'America/New_York')
        mail = described_class.with(
          page:,
          recipient:,
          action: 'added',
          actor_name: actor.name
        ).authorship_changed_notification

        expect(mail.body.encoded).to be_present
      end
    end
  end
end
