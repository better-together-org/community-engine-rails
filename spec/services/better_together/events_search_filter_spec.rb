# frozen_string_literal: true

require 'rails_helper'

# RED-phase acceptance criteria for AC-3.1 through AC-3.5 (docs/implementation/
# current_plans/event_occurrences_acceptance_criteria.md). The filter's date
# window/order still key off the static `starts_at` column today — every
# `pending` example here is written against the planned `next_occurrence_at`
# behavior and is expected to fail until Part 3 lands. AC-3.6 is a standing
# regression guard (already true today) and is intentionally NOT pending —
# it must keep passing throughout the Part 3 implementation.
RSpec.describe BetterTogether::EventsSearchFilter do
  let(:stale_recurring_event) do
    create(:better_together_event, name: 'Weekly Standup', starts_at: 2.months.ago)
  end
  let(:recurring_upcoming_event) do
    create(:better_together_event, name: 'Weekly Book Club', starts_at: 1.week.from_now)
  end
  let(:genuinely_past_event) do
    create(:better_together_event, name: 'One-time Kickoff', starts_at: 1.month.ago)
  end
  let(:one_time_upcoming_event) do
    create(:better_together_event, name: 'One-time Launch Party', starts_at: 1.week.from_now)
  end

  before do
    create(:recurrence, :weekly, schedulable: stale_recurring_event)
    create(:recurrence, :weekly, schedulable: recurring_upcoming_event)
    stale_recurring_event.reload
    recurring_upcoming_event.reload
    genuinely_past_event
    one_time_upcoming_event
  end

  def filtered(params)
    described_class.call(relation: BetterTogether::Event.all, params:)
  end

  describe 'default "upcoming" view (AC-3.1)' do
    it 'includes a recurring event whose original starts_at is in the past, and still excludes a genuinely past one' do
      pending 'AC-3.1: filter_by_date_range does not yet consult next_occurrence_at'

      results = filtered({})
      expect(results).to include(stale_recurring_event)
      expect(results).not_to include(genuinely_past_event)
    end
  end

  describe '"past" filter (AC-3.2)' do
    it 'excludes a still-recurring event, and still includes a genuinely one-time past event' do
      pending 'AC-3.2: past filter must also key off next_occurrence_at'

      results = filtered({ past: '1' })
      expect(results).not_to include(stale_recurring_event)
      expect(results).to include(genuinely_past_event)
    end
  end

  describe 'sort order reflects true next occurrence (AC-3.3)' do
    it 'orders a recurring event by its next occurrence date, not its stale original starts_at' do
      pending 'AC-3.3: default_order_by does not yet use next_occurrence_at'

      results = filtered({}).to_a
      expect(results.index(stale_recurring_event)).to be < results.index(one_time_upcoming_event)
    end
  end

  describe 'override-aware next occurrence (AC-3.4)' do
    it 'reflects an organizer\'s override of the very next occurrence in sort position and displayed date' do
      pending 'AC-3.4: EventOccurrence override merge into next_occurrence_at not yet implemented'

      recurrence = stale_recurring_event.recurrence
      next_date = recurrence.occurrences_between(Time.current, 1.year.from_now).first.to_date
      occurrence = BetterTogether::EventOccurrence.create!(event: stale_recurring_event, occurrence_date: next_date)
      overridden_time = occurrence.effective_starts_at + 3.days
      occurrence.update!(starts_at: overridden_time)

      expect(stale_recurring_event.reload.next_occurrence_at).to eq(overridden_time)
    end
  end

  describe 'recurring-only / one-time-only filter (AC-3.5)' do
    # Both candidate events are genuinely upcoming here (unlike stale_recurring_event),
    # so today's next_occurrence_at-less filter can't accidentally "pass" this by
    # coincidentally time-filtering one of them out — the only thing that should ever
    # distinguish these results is whether the `recurring` param is honored.
    it 'filters to recurring events only' do
      pending 'AC-3.5: recurring tri-state filter param not yet implemented'

      results = filtered({ recurring: 'true' })

      expect(results).to include(recurring_upcoming_event)
      expect(results).not_to include(one_time_upcoming_event)
    end

    it 'filters to one-time events only' do
      pending 'AC-3.5: recurring tri-state filter param not yet implemented'

      results = filtered({ recurring: 'false' })

      expect(results).to include(one_time_upcoming_event)
      expect(results).not_to include(recurring_upcoming_event)
    end
  end

  describe 'pagination stays a real paginated SQL relation (AC-3.6)' do
    it 'returns a Kaminari-paginated ActiveRecord::Relation, not an in-memory array — must hold before, during, and after Part 3' do
      results = filtered({ per_page: '10', page: '1' })

      expect(results).to respond_to(:total_count)
      expect(results).to be_a(ActiveRecord::Relation)
    end
  end
end
