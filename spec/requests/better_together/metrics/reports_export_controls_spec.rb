# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Metrics reports export controls', :as_platform_manager do
  let(:locale) { I18n.default_locale }

  it 'renders export actions for charts' do
    get better_together.metrics_reports_path(locale: locale)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('better_together--metrics-charts#exportPng')
    expect(response.body).to include('better_together--metrics-charts#exportCsv')
    expect(response.body).to include('better_together--metrics-charts#exportJpg')
  end
end
