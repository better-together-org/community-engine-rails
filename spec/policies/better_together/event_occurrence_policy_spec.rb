# frozen_string_literal: true

require 'rails_helper'

# RED-phase acceptance criteria for BetterTogether::EventOccurrencePolicy.
# See docs/implementation/current_plans/event_occurrences_acceptance_criteria.md,
# Phase 0 (AC-0.5, AC-0.6, AC-0.7) and Phase 2 (AC-2.3). Neither the policy
# class nor EventOccurrence exist yet — every example is expected to fail
# until Part 0 lands; `pending` will flag loudly if one passes early.
RSpec.describe 'BetterTogether::EventOccurrencePolicy' do
  let(:host_community) { BetterTogether::Platform.find_by(host: true).community }
  let(:organizer) { create(:better_together_user) }
  let(:other_user) { create(:better_together_user) }
  let(:event) { create(:better_together_event, creator: organizer.person) }
  let(:recurrence) { create(:recurrence, :weekly, schedulable: event) }
  let(:occurrence_date) { recurrence.occurrences_between(Time.current, 1.year.from_now).first.to_date }

  before do
    event.event_hosts.create!(host: organizer.person)
  end

  describe 'authorization delegates to the parent event, never duplicates hosting (AC-0.5, AC-0.6)' do
    it 'authorizes an occurrence update for the parent event\'s creator/host, without duplicating any EventHost row' do
      pending 'AC-0.5/AC-0.6: EventOccurrencePolicy not yet implemented'

      expect do
        occurrence = BetterTogether::EventOccurrence.create!(event:, occurrence_date:)
        expect(BetterTogether::EventOccurrencePolicy.new(organizer, occurrence).update?).to be true
      end.not_to change(BetterTogether::EventHost, :count)
    end

    it 'denies a non-host, non-creator person from overriding or cancelling any occurrence (AC-2.3)' do
      pending 'AC-2.3: EventOccurrencePolicy denial path not yet implemented'

      occurrence = BetterTogether::EventOccurrence.create!(event:, occurrence_date:)

      expect(BetterTogether::EventOccurrencePolicy.new(other_user, occurrence).update?).to be false
    end
  end

  describe 'reuses EventPolicy\'s host-membership logic via a shared concern, not a duplicate copy (AC-0.5)' do
    it 'grants the same access an equivalent EventPolicy check would grant' do
      pending 'AC-0.5: shared EventHostAuthorizable concern not yet extracted'

      occurrence = BetterTogether::EventOccurrence.create!(event:, occurrence_date:)
      event_level_access = BetterTogether::EventPolicy.new(organizer, event).update?
      occurrence_level_access = BetterTogether::EventOccurrencePolicy.new(organizer, occurrence).update?

      expect(occurrence_level_access).to eq(event_level_access)
    end
  end

  describe 'no per-occurrence permission grant is required beyond parent event management rights (AC-0.7)' do
    it 'authorizes every occurrence of a series identically based on the one parent event grant' do
      pending 'AC-0.7: consistent cross-occurrence authorization not yet implemented'

      occurrence_a = BetterTogether::EventOccurrence.create!(event:, occurrence_date:)
      later_date = recurrence.occurrences_between(3.weeks.from_now, 2.years.from_now).first.to_date
      occurrence_b = BetterTogether::EventOccurrence.create!(event:, occurrence_date: later_date)

      expect(BetterTogether::EventOccurrencePolicy.new(organizer, occurrence_a).update?).to be true
      expect(BetterTogether::EventOccurrencePolicy.new(organizer, occurrence_b).update?).to be true
    end
  end
end
