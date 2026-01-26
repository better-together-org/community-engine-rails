# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/ModuleLength
module BetterTogether
  RSpec.describe Recurrence do
    include ActiveSupport::Testing::TimeHelpers

    let(:event) { create(:event, starts_at: Time.zone.parse('2026-01-15 14:00')) }
    let(:schedule) do
      s = ::IceCube::Schedule.new(event.starts_at)
      s.add_recurrence_rule(::IceCube::Rule.weekly(1))
      s
    end
    let(:rule) { schedule.to_yaml }

    describe 'associations' do
      it { is_expected.to belong_to(:schedulable) }
    end

    describe 'validations' do
      subject(:recurrence) { build(:recurrence, schedulable: event, rule: rule) }

      it { is_expected.to validate_presence_of(:rule) }

      it 'validates frequency inclusion' do
        # Frequency is auto-extracted from rule, so test with known good rule
        # The validation ensures frequency is one of: daily, weekly, monthly, yearly
        recurrence.save!
        expect(recurrence.frequency).to be_in(%w[daily weekly monthly yearly])
      end

      it 'validates rule format' do
        recurrence.rule = 'invalid yaml'
        expect(recurrence).not_to be_valid
        expect(recurrence.errors[:rule]).to include(/is invalid/)
      end

      it 'accepts valid ice_cube YAML' do
        recurrence.rule = rule
        expect(recurrence).to be_valid
      end
    end

    describe '#schedule' do
      let(:recurrence) { create(:recurrence, schedulable: event, rule: rule) }

      it 'returns an IceCube::Schedule object' do
        expect(recurrence.schedule).to be_a(IceCube::Schedule)
      end

      it 'returns nil when rule is blank' do
        recurrence.rule = nil
        expect(recurrence.schedule).to be_nil
      end
    end

    describe '#recurring?' do
      it 'returns true when rule is present' do
        recurrence = build(:recurrence, rule: rule)
        expect(recurrence).to be_recurring
      end

      it 'returns false when rule is blank' do
        recurrence = build(:recurrence, rule: nil)
        expect(recurrence).not_to be_recurring
      end
    end

    describe '#occurrences_between' do
      let(:recurrence) { create(:recurrence, schedulable: event, rule: rule) }
      let(:start_date) { Time.zone.parse('2026-01-15') }
      let(:end_date) { Time.zone.parse('2026-02-15') }

      it 'returns occurrences within the date range' do
        occurrences = recurrence.occurrences_between(start_date, end_date)
        expect(occurrences.length).to be > 0
        expect(occurrences.first).to be_a(Time)
      end

      it 'excludes exception dates' do
        exception_date = Time.zone.parse('2026-01-22 14:00').to_date
        recurrence.exception_dates = [exception_date]
        recurrence.save!

        occurrences = recurrence.occurrences_between(start_date, end_date)
        occurrence_dates = occurrences.map(&:to_date)

        expect(occurrence_dates).not_to include(exception_date)
      end

      it 'returns empty array when no schedule' do
        recurrence.rule = nil
        expect(recurrence.occurrences_between(start_date, end_date)).to eq([])
      end
    end

    describe '#next_occurrence' do
      let(:recurrence) { create(:recurrence, schedulable: event, rule: rule) }

      it 'returns the next occurrence after current time' do
        travel_to Time.zone.parse('2026-01-16 12:00') do
          next_occ = recurrence.next_occurrence
          expect(next_occ).to be_a(Time)
          expect(next_occ).to be > Time.current
        end
      end

      it 'skips exception dates' do
        exception_date = Time.zone.parse('2026-01-22 14:00').to_date
        recurrence.exception_dates = [exception_date]
        recurrence.save!

        travel_to Time.zone.parse('2026-01-21 12:00') do
          next_occ = recurrence.next_occurrence
          # Should skip 1/22 and go to 1/29
          expect(next_occ.to_date).to eq(Time.zone.parse('2026-01-29').to_date)
        end
      end

      it 'respects ends_on date' do
        recurrence.ends_on = Date.parse('2026-01-20')
        recurrence.save!

        travel_to Time.zone.parse('2026-01-25 12:00') do
          expect(recurrence.next_occurrence).to be_nil
        end
      end

      it 'returns nil when no schedule' do
        recurrence.rule = nil
        expect(recurrence.next_occurrence).to be_nil
      end
    end

    describe '#add_exception_date' do
      let(:recurrence) { create(:recurrence, schedulable: event, rule: rule) }
      let(:date) { Date.parse('2026-01-22') }

      it 'adds a date to exception_dates' do
        recurrence.add_exception_date(date)
        expect(recurrence.exception_dates).to include(date)
      end

      it 'does not add duplicate dates' do
        recurrence.add_exception_date(date)
        recurrence.add_exception_date(date)
        expect(recurrence.exception_dates.count(date)).to eq(1)
      end
    end

    describe '#remove_exception_date' do
      let(:recurrence) do
        create(:recurrence,
               schedulable: event,
               rule: rule,
               exception_dates: [Date.parse('2026-01-22')])
      end
      let(:date) { Date.parse('2026-01-22') }

      it 'removes a date from exception_dates' do
        recurrence.remove_exception_date(date)
        expect(recurrence.exception_dates).not_to include(date)
      end
    end

    describe '#extract_frequency_from_rule' do
      it 'extracts daily frequency' do
        daily_schedule = ::IceCube::Schedule.new(event.starts_at)
        daily_schedule.add_recurrence_rule(::IceCube::Rule.daily(1))
        recurrence = create(:recurrence, schedulable: event, rule: daily_schedule.to_yaml)

        expect(recurrence.frequency).to eq('daily')
      end

      it 'extracts weekly frequency' do
        recurrence = create(:recurrence, schedulable: event, rule: rule)
        expect(recurrence.frequency).to eq('weekly')
      end

      it 'extracts monthly frequency' do
        monthly_schedule = ::IceCube::Schedule.new(event.starts_at)
        monthly_schedule.add_recurrence_rule(::IceCube::Rule.monthly(1))
        recurrence = create(:recurrence, schedulable: event, rule: monthly_schedule.to_yaml)

        expect(recurrence.frequency).to eq('monthly')
      end

      it 'extracts yearly frequency' do
        yearly_schedule = ::IceCube::Schedule.new(event.starts_at)
        yearly_schedule.add_recurrence_rule(::IceCube::Rule.yearly(1))
        recurrence = create(:recurrence, schedulable: event, rule: yearly_schedule.to_yaml)

        expect(recurrence.frequency).to eq('yearly')
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength
