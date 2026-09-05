# frozen_string_literal: true

require 'rails_helper'

# Acceptance criteria for BetterTogether::EventOccurrence. See
# docs/implementation/current_plans/event_occurrences_acceptance_criteria.md.
#
# Described by string, not the bare constant, for historical reasons (kept
# for consistency with sibling spec files written the same way): avoids any
# risk of RSpec.describe resolving the constant at file-load time.
RSpec.describe 'BetterTogether::EventOccurrence' do
  let(:event) do
    create(:better_together_event, name: 'Weekly Standup', starts_at: 1.week.ago)
  end
  let(:recurrence) { create(:recurrence, :weekly, schedulable: event) }
  let(:real_occurrence_date) { recurrence.occurrences_between(Time.current, 1.year.from_now).first.to_date }

  describe 'lazy creation (AC-0.1, AC-0.4)' do
    it 'creates exactly one row for a given event+date pair, not one per occurrence up front' do
      recurrence
      expect do
        event.find_or_create_occurrence_for(real_occurrence_date)
      end.to change(BetterTogether::EventOccurrence, :count).by(1)
    end

    it 'does not create a row merely from computing/viewing occurrences' do
      recurrence
      expect do
        event.occurrences_between(Time.current, 1.year.from_now)
      end.not_to change(BetterTogether::EventOccurrence, :count)
    end
  end

  describe 'date validity (AC-0.3)' do
    it 'rejects an occurrence_date that the recurrence rule does not actually produce' do
      recurrence
      bogus = BetterTogether::EventOccurrence.new(event:, occurrence_date: Date.new(1999, 1, 1))

      expect(bogus).not_to be_valid
    end
  end

  describe 'uniqueness' do
    it 'enforces one row per event per occurrence_date' do
      recurrence
      BetterTogether::EventOccurrence.create!(event:, occurrence_date: real_occurrence_date)
      duplicate = BetterTogether::EventOccurrence.new(event:, occurrence_date: real_occurrence_date)

      expect(duplicate).not_to be_valid
    end
  end

  describe 'effective_* fallback and override behavior (AC-2.1, AC-2.2, AC-2.5)' do
    it 'falls back to the computed default when no override is set' do
      occurrence = BetterTogether::EventOccurrence.create!(event:, occurrence_date: real_occurrence_date)

      expect(occurrence.effective_starts_at.to_date).to eq(real_occurrence_date)
    end

    it 'returns the override value when one has been set, not the computed default' do
      occurrence = BetterTogether::EventOccurrence.create!(event:, occurrence_date: real_occurrence_date)
      overridden_time = occurrence.effective_starts_at + 2.hours
      occurrence.update!(starts_at: overridden_time)

      expect(occurrence.effective_starts_at).to eq(overridden_time)
    end

    it 'overriding one occurrence never touches the base Recurrence rule or other occurrences' do
      recurrence
      occurrence = BetterTogether::EventOccurrence.create!(event:, occurrence_date: real_occurrence_date)
      original_rule = event.recurrence.rule

      occurrence.update!(starts_at: occurrence.effective_starts_at + 3.hours, cancelled: true)

      expect(event.recurrence.reload.rule).to eq(original_rule)
    end
  end

  describe 'cancellation preserves history (AC-2.4)' do
    it 'cancelling an occurrence does not destroy its own record or associated attendance' do
      occurrence = BetterTogether::EventOccurrence.create!(event:, occurrence_date: real_occurrence_date)
      person = create(:better_together_person)
      BetterTogether::EventAttendance.create!(event:, event_occurrence: occurrence, person:, status: 'going')

      occurrence.update!(cancelled: true)

      expect(occurrence).to be_persisted
      expect(occurrence.event_attendances.reload).not_to be_empty
    end
  end

  describe 'Commentable (AC-1.5, AC-1.6)' do
    it 'is commentable, independently per occurrence' do
      occurrence_a = BetterTogether::EventOccurrence.create!(event:, occurrence_date: real_occurrence_date)
      occurrence_b_date = recurrence.occurrences_between(1.week.from_now, 2.years.from_now).first.to_date
      occurrence_b = BetterTogether::EventOccurrence.create!(event:, occurrence_date: occurrence_b_date)
      commenter = create(:better_together_person)

      occurrence_a.comments.create!(creator: commenter, content: 'See you at this one!')

      expect(occurrence_b.comments.reload).to be_empty
    end
  end
end
