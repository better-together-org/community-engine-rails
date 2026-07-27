# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::RecurrenceHelper do
  describe '#recurrence_frequency_options' do
    it 'returns frequency options' do
      expect(helper.recurrence_frequency_options).to eq([
                                                          ['Daily', :daily],
                                                          ['Weekly', :weekly],
                                                          ['Monthly', :monthly],
                                                          ['Yearly', :yearly]
                                                        ])
    end
  end

  describe '#recurrence_end_type_options' do
    it 'returns end type options' do
      expect(helper.recurrence_end_type_options).to eq([
                                                         ['Never', 'never'],
                                                         ['On date', 'until'],
                                                         ['After occurrences', 'count']
                                                       ])
    end
  end

  describe '#weekday_checkboxes' do
    let(:event) { build_stubbed(:event) }
    let(:form) { instance_double(ActionView::Helpers::FormBuilder, object_name: 'event') }

    it 'generates checkboxes for all weekdays' do
      result = helper.weekday_checkboxes(form)

      Date::DAYNAMES.each do |day|
        expect(result).to include(day)
      end
    end

    it 'includes form-check classes' do
      result = helper.weekday_checkboxes(form)
      expect(result).to include('form-check')
      expect(result).to include('form-check-input')
      expect(result).to include('form-check-label')
    end

    it 'checks selected days' do
      result = helper.weekday_checkboxes(form, selected_days: [1, 3]) # Monday and Wednesday
      expect(result).to include('checked')
    end

    it 'checks the correct boxes for the real Symbol output of Recurrence#weekdays' do
      # Regression test: Recurrence#weekdays returns Symbols (e.g. :monday),
      # not the Integer indices weekday_checkboxes compares against directly.
      # Round-tripping through RecurrenceScheduleBuilder.weekday_indices_for
      # (as the real view call site does) is what must produce matching
      # checkboxes — passing recurrence.weekdays straight through used to
      # silently check nothing at all.
      schedule = IceCube::Schedule.new(Time.zone.parse('2026-01-05 10:00')) # a Monday
      schedule.add_recurrence_rule(IceCube::Rule.weekly(1).day(:monday, :wednesday))
      # #weekdays only returns anything when frequency == 'weekly', and
      # frequency is normally extracted from the rule by a before_validation
      # callback — build_stubbed skips callbacks, so set it explicitly here.
      recurrence = build_stubbed(:recurrence, rule: schedule.to_yaml, frequency: 'weekly')

      indices = BetterTogether::RecurrenceScheduleBuilder.weekday_indices_for(recurrence)
      result = helper.weekday_checkboxes(form, selected_days: indices)
      fragment = Nokogiri::HTML::DocumentFragment.parse(result)
      checked_values = fragment.css('input[type="checkbox"][checked]').map { |node| node['value'] }

      expect(indices).to contain_exactly(1, 3) # Monday, Wednesday
      expect(checked_values).to contain_exactly('1', '3')
    end
  end

  describe '#format_recurrence_rule' do
    it 'returns "Does not repeat" for nil recurrence' do
      expect(helper.format_recurrence_rule(nil)).to eq('Does not repeat')
    end

    it 'returns "Does not repeat" for non-recurring recurrence' do
      recurrence = build_stubbed(:recurrence, rule: nil)
      allow(recurrence).to receive(:recurring?).and_return(false)
      expect(helper.format_recurrence_rule(recurrence)).to eq('Does not repeat')
    end

    it 'formats weekly recurrence' do
      recurrence = build_stubbed(:recurrence, :weekly)
      result = helper.format_recurrence_rule(recurrence)
      expect(result).to include('Weekly')
    end

    it 'includes end date when present' do
      ends_on = 3.months.from_now.to_date
      recurrence = build_stubbed(:recurrence, :weekly, ends_on: ends_on)
      result = helper.format_recurrence_rule(recurrence)
      expect(result).to include('until')
    end
  end

  describe '#next_occurrences_list' do
    let(:event) { create(:event, starts_at: 1.week.from_now) }

    it 'returns "Does not repeat" message for non-recurring events' do
      result = helper.next_occurrences_list(event)
      expect(result).to include('Does not repeat')
    end

    it 'displays list of next occurrences for recurring events' do
      event.create_recurrence!(rule: create(:recurrence, :weekly).rule)
      result = helper.next_occurrences_list(event, count: 3)
      expect(result).to include('<ul')
      expect(result).to include('<li')
    end
  end
end
