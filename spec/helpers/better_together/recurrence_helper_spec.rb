# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe RecurrenceHelper do
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
end
