# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ContentSecurity::MailSubjectSync do
  subject(:call) { described_class.new(message:).call }

  describe '#call' do
    context 'when the message screening_state is passed' do
      let(:message) { create(:inbound_email_message, screening_state: 'passed', screening_verdict: 'clean') }

      it 'does not create a Subject' do
        expect { call }.not_to change(BetterTogether::ContentSecurity::Subject, :count)
      end
    end

    context 'when the message screening_state is held' do
      let(:message) { create(:inbound_email_message, screening_state: 'held', screening_verdict: 'quarantined') }

      it 'creates a Subject for the message' do
        expect { call }.to change(BetterTogether::ContentSecurity::Subject, :count).by(1)
      end

      it 'sets the subject association to the message' do
        subject_record = call
        expect(subject_record.subject).to eq(message)
      end

      it 'sets the attachment_name to the mail constant' do
        subject_record = call
        expect(subject_record.attachment_name).to eq('inbound_email')
      end

      it 'sets the source_surface' do
        subject_record = call
        expect(subject_record.source_surface).to eq('ce_inbound_mail')
      end

      it 'sets a storage_ref referencing the message id' do
        subject_record = call
        expect(subject_record.storage_ref).to eq("inbound_email_message/#{message.id}")
      end

      it 'lands in the review queue' do
        subject_record = call
        expect(BetterTogether::ContentSecurity::Subject.review_queue).to include(subject_record)
      end

      it 'is not released for human access' do
        subject_record = call
        expect(subject_record).not_to be_released_for_human_access
      end
    end

    context 'when the message screening_state is error' do
      let(:message) { create(:inbound_email_message, screening_state: 'error', screening_verdict: 'review_required') }

      it 'creates a Subject for the message' do
        expect { call }.to change(BetterTogether::ContentSecurity::Subject, :count).by(1)
      end
    end

    context 'when called twice for the same held message' do
      let(:message) { create(:inbound_email_message, screening_state: 'held', screening_verdict: 'restricted') }

      it 'does not create a duplicate Subject' do
        described_class.new(message:).call
        expect { described_class.new(message:).call }.not_to change(BetterTogether::ContentSecurity::Subject, :count)
      end
    end
  end
end
