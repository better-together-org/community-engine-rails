# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::DatetimeFilterable, type: :concern do
  let(:test_class) do
    Class.new(ApplicationController) do
      include BetterTogether::Metrics::DatetimeFilterable

      def index
        scope = filter_by_datetime(BetterTogether::Metrics::PageView, :viewed_at)
        render json: { count: scope.count }
      end
    end
  end

  let(:controller) { test_class.new }
  let(:params) { {} }

  before do
    allow(controller).to receive(:params).and_return(ActionController::Parameters.new(params))
    allow(controller).to receive(:render)
  end

  describe '#set_datetime_range' do
    context 'when no date parameters provided' do
      it 'sets default start_date to 30 days ago' do
        controller.send(:set_datetime_range)
        expect(controller.instance_variable_get(:@start_date)).to be_within(1.minute).of(30.days.ago.beginning_of_day)
      end

      it 'sets default end_date to current time' do
        controller.send(:set_datetime_range)
        expect(controller.instance_variable_get(:@end_date)).to be_within(1.minute).of(Time.current.end_of_day)
      end
    end

    context 'when valid date parameters provided' do
      let(:start_date) { 7.days.ago.iso8601 }
      let(:end_date) { Time.current.iso8601 }
      let(:params) { { start_date: start_date, end_date: end_date } }

      it 'parses and sets start_date correctly' do
        controller.send(:set_datetime_range)
        expect(controller.instance_variable_get(:@start_date)).to be_within(1.second).of(Time.zone.parse(start_date))
      end

      it 'parses and sets end_date correctly' do
        controller.send(:set_datetime_range)
        expect(controller.instance_variable_get(:@end_date)).to be_within(1.second).of(Time.zone.parse(end_date))
      end
    end

    context 'when start_date is after end_date' do
      let(:params) { { start_date: Time.current.iso8601, end_date: 1.day.ago.iso8601 } }

      it 'renders an error response' do
        expect(controller).to receive(:render).with(
          json: { error: I18n.t('better_together.metrics.errors.invalid_date_range') },
          status: :unprocessable_content
        )
        controller.send(:set_datetime_range)
      end
    end

    context 'when date range exceeds 1 year' do
      let(:params) { { start_date: 2.years.ago.iso8601, end_date: Time.current.iso8601 } }

      it 'renders an error response' do
        expect(controller).to receive(:render).with(
          json: { error: I18n.t('better_together.metrics.errors.date_range_too_large') },
          status: :unprocessable_content
        )
        controller.send(:set_datetime_range)
      end
    end

    context 'when date parameter is invalid' do
      let(:params) { { start_date: 'invalid-date' } }

      it 'uses default start_date' do
        controller.send(:set_datetime_range)
        expect(controller.instance_variable_get(:@start_date)).to be_within(1.minute).of(30.days.ago.beginning_of_day)
      end
    end
  end

  describe '#parse_date_param' do
    it 'parses valid ISO 8601 date string' do
      date_string = '2024-01-15T10:30:00Z'
      result = controller.send(:parse_date_param, date_string)
      expect(result).to eq(Time.zone.parse(date_string))
    end

    it 'returns nil for blank string' do
      expect(controller.send(:parse_date_param, '')).to be_nil
    end

    it 'returns nil for nil value' do
      expect(controller.send(:parse_date_param, nil)).to be_nil
    end

    it 'returns nil for invalid date string' do
      expect(controller.send(:parse_date_param, 'not-a-date')).to be_nil
    end
  end

  describe '#filter_by_datetime' do
    let!(:old_record) { create(:metrics_page_view, viewed_at: 40.days.ago) }
    let!(:recent_record) { create(:metrics_page_view, viewed_at: 5.days.ago) }
    let!(:new_record) { create(:metrics_page_view, viewed_at: 1.day.ago) }

    before do
      controller.send(:set_datetime_range)
    end

    it 'filters records within the date range' do
      scope = controller.send(:filter_by_datetime, BetterTogether::Metrics::PageView, :viewed_at)
      expect(scope).to include(recent_record, new_record)
      expect(scope).not_to include(old_record)
    end

    it 'returns ActiveRecord::Relation' do
      scope = controller.send(:filter_by_datetime, BetterTogether::Metrics::PageView, :viewed_at)
      expect(scope).to be_a(ActiveRecord::Relation)
    end
  end
end
