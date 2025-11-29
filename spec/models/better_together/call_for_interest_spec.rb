# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # rubocop:disable Metrics/ModuleLength
  RSpec.describe CallForInterest do
    describe 'factory' do
      it 'creates a valid call for interest' do
        call = build(:call_for_interest)
        expect(call).to be_valid
      end

      it 'creates draft calls for interest' do
        call = create(:call_for_interest, :draft)
        expect(call.starts_at).to be_nil
        expect(call.ends_at).to be_nil
      end

      it 'creates calls with events' do
        call = create(:call_for_interest, :with_event)
        expect(call.interestable).to be_an(Event)
      end
    end

    describe 'associations' do
      it { is_expected.to belong_to(:interestable).optional }
      it { is_expected.to belong_to(:creator) }
    end

    describe 'validations' do
      it 'validates cover image content type' do
        call = build(:call_for_interest)
        expect(call).to be_valid
      end
    end

    describe 'translatable attributes' do
      it 'has translatable name' do
        call = create(:call_for_interest, name: 'Test Call')
        expect(call.name).to eq('Test Call')
      end

      it 'has translatable description' do
        call = create(:call_for_interest, description: 'Test Description')
        expect(call.description).to be_present
      end
    end

    describe 'scopes' do
      let!(:draft_call) { create(:call_for_interest, :draft) }
      let!(:upcoming_call) { create(:call_for_interest, :upcoming) }
      let!(:past_call) { create(:call_for_interest, :past) }

      describe '.draft' do
        it 'returns only draft calls' do
          expect(described_class.draft).to include(draft_call)
          expect(described_class.draft).not_to include(upcoming_call, past_call)
        end
      end

      describe '.upcoming' do
        it 'returns only upcoming calls' do
          expect(described_class.upcoming).to include(upcoming_call)
          expect(described_class.upcoming).not_to include(past_call, draft_call)
        end
      end

      describe '.past' do
        it 'returns only past calls' do
          expect(described_class.past).to include(past_call)
          expect(described_class.past).not_to include(upcoming_call, draft_call)
        end
      end
    end

    describe 'privacy levels' do
      it 'supports public privacy' do
        call = create(:call_for_interest, privacy: 'public')
        expect(call.privacy).to eq('public')
      end

      it 'supports private privacy' do
        call = create(:call_for_interest, :private)
        expect(call.privacy).to eq('private')
      end
    end

    describe 'polymorphic interestable' do
      it 'can be associated with an event' do
        event = create(:event)
        call = create(:call_for_interest, interestable: event)

        expect(call.interestable).to eq(event)
        expect(call.interestable_type).to eq('BetterTogether::Event')
      end

      it 'allows nil interestable' do
        call = create(:call_for_interest, interestable: nil)
        expect(call.interestable).to be_nil
      end
    end

    describe 'timing attributes' do
      it 'tracks starts_at' do
        time = 1.week.from_now
        call = create(:call_for_interest, starts_at: time)
        expect(call.starts_at).to be_within(1.second).of(time)
      end

      it 'tracks ends_at' do
        time = 2.weeks.from_now
        call = create(:call_for_interest, ends_at: time)
        expect(call.ends_at).to be_within(1.second).of(time)
      end

      it 'allows nil starts_at for drafts' do
        call = create(:call_for_interest, :draft)
        expect(call.starts_at).to be_nil
      end

      it 'allows nil ends_at' do
        call = create(:call_for_interest, starts_at: 1.week.from_now, ends_at: nil)
        expect(call.ends_at).to be_nil
      end
    end

    describe 'identifier behavior' do
      it 'generates unique identifiers' do
        call1 = create(:call_for_interest)
        call2 = create(:call_for_interest)

        expect(call1.identifier).to be_present
        expect(call2.identifier).to be_present
        expect(call1.identifier).not_to eq(call2.identifier)
      end
    end
  end
end
