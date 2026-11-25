# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::WeatherPolicy, :weather_stewards do
  let(:record) { :weather }

  before { weather_host_platform }

  it_behaves_like 'a host steward weather policy', %i[index? show? update? toggle?]
end
