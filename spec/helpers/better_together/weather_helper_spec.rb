# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::WeatherHelper do
  describe '#weather_value' do
    it 'renders nil as not reported, never zero' do
      expect(helper.weather_value(nil, :mm)).to eq(I18n.t('better_together.weather.panel.not_reported'))
    end

    it 'keeps a genuine zero' do
      expect(helper.weather_value(0, :mm)).to eq('0 mm')
    end

    it 'formats with the unit and strips trailing zeros' do
      expect(helper.weather_value(4.0, :celsius)).to eq('4 °C')
      expect(helper.weather_value(4.25, :celsius, digits: 1)).to eq('4.3 °C')
    end
  end

  describe '#weather_day_label' do
    let(:date) { Date.new(2026, 11, 5) }

    it 'marks a partial day' do
      expect(helper.weather_day_label(date, partial: true))
        .to end_with("(#{I18n.t('better_together.weather.panel.history.so_far')})")
    end

    %i[en es fr uk].each do |locale|
      it "localizes the abbreviated month in #{locale}" do
        I18n.with_locale(locale) do
          expected = I18n.t('date.abbr_month_names', locale: locale)[11]
          expect(helper.weather_day_label(date)).to include(expected)
        end
      end
    end
  end

  describe '#weather_time' do
    it 'converts an ISO string into the given zone' do
      expect(helper.weather_time('2026-11-10T15:30:00Z', ActiveSupport::TimeZone['America/St_Johns'])).to eq('12:00')
    end

    it 'is nil when blank' do
      expect(helper.weather_time(nil, 'UTC')).to be_nil
    end
  end
end
