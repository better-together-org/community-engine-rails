# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonDeletionAnonymizer, type: :service do
  let(:person) { create(:better_together_person) }

  describe '.call' do
    it 'sets name to the deleted placeholder' do
      described_class.call(person: person)
      expect(person.reload.name).to eq('Deleted person')
    end

    it 'sets identifier to the deleted-person prefix followed by id fragment' do
      described_class.call(person: person)
      expected_prefix = "deleted-person-#{person.id.delete('-').first(12)}"
      expect(person.reload.identifier).to eq(expected_prefix)
    end

    it 'sets privacy to private' do
      described_class.call(person: person)
      expect(person.reload.privacy).to eq('private')
    end

    it 'sets deleted_at timestamp' do
      travel_to(Time.current) do
        described_class.call(person: person)
        expect(person.reload.deleted_at).to be_within(2.seconds).of(Time.current)
      end
    end

    it 'sets anonymized_at timestamp' do
      travel_to(Time.current) do
        described_class.call(person: person)
        expect(person.reload.anonymized_at).to be_within(2.seconds).of(Time.current)
      end
    end

    it 'clears cryptographic key fields' do
      described_class.call(person: person)
      reloaded = person.reload
      expect(reloaded.identity_key_public).to be_nil
      expect(reloaded.signed_prekey_public).to be_nil
      expect(reloaded.registration_id).to be_nil
      expect(reloaded.key_backup_blob).to be_nil
    end

    it 'sets default notification preferences disabling email' do
      described_class.call(person: person)
      prefs = person.reload.notification_preferences
      expect(prefs['notify_by_email']).to be false
    end

    it 'sets default preferences disabling federation' do
      described_class.call(person: person)
      prefs = person.reload.preferences
      expect(prefs['federate_content']).to be false
    end

    context 'when person has a ContactDetail' do
      it 'destroys the ContactDetail' do
        create(:better_together_contact_detail, contactable: person)

        expect do
          described_class.call(person: person)
        end.to change(BetterTogether::ContactDetail, :count).by(-1)
      end
    end
  end
end
