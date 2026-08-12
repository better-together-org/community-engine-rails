# frozen_string_literal: true

require 'rails_helper'

# Acceptance criteria for AC-3.7 (docs/implementation/current_plans/
# event_occurrences_acceptance_criteria.md).
RSpec.describe 'BetterTogether::EventNextOccurrenceRefreshScanJob' do
  let(:event) { create(:better_together_event, starts_at: 2.months.ago) }
  let(:non_recurring_event) { create(:better_together_event, starts_at: 1.week.from_now) }

  before { create(:recurrence, :weekly, schedulable: event) }

  it 'advances a recurring event whose stored next_occurrence_at has passed (AC-3.7)' do
    event.update_columns(next_occurrence_at: 1.day.ago) # rubocop:disable Rails/SkipsModelValidations

    BetterTogether::EventNextOccurrenceRefreshScanJob.perform_now

    expect(event.reload.next_occurrence_at).to be > Time.current
  end

  it 'does not touch a recurring event whose next_occurrence_at is already in the future' do
    future_time = 3.days.from_now
    event.update_columns(next_occurrence_at: future_time) # rubocop:disable Rails/SkipsModelValidations

    expect do
      BetterTogether::EventNextOccurrenceRefreshScanJob.perform_now
    end.not_to(change { event.reload.next_occurrence_at })
  end

  it 'does not raise or abort the batch when one record fails to refresh' do
    event.update_columns(next_occurrence_at: 1.day.ago) # rubocop:disable Rails/SkipsModelValidations
    # allow_any_instance_of is deliberate here: the job queries and instantiates its
    # own Event record internally, so a specific-instance stub on `event` would never
    # intercept it.
    allow_any_instance_of(BetterTogether::Event) # rubocop:disable RSpec/AnyInstance
      .to receive(:refresh_next_occurrence_at!).and_raise(StandardError)

    expect { BetterTogether::EventNextOccurrenceRefreshScanJob.perform_now }.not_to raise_error
  end

  it 'leaves a non-recurring event\'s next_occurrence_at as its own starts_at, untouched by the scan' do
    non_recurring_event.update_columns( # rubocop:disable Rails/SkipsModelValidations
      next_occurrence_at: non_recurring_event.starts_at
    )

    expect do
      BetterTogether::EventNextOccurrenceRefreshScanJob.perform_now
    end.not_to(change { non_recurring_event.reload.next_occurrence_at })
  end
end
