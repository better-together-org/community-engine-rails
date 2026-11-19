# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Weather::SourcePolicy, :weather_stewards do
  let(:record) { create(:weather_source) }

  before { weather_host_platform }

  it_behaves_like 'a host steward weather policy', %i[index? update? toggle?]
end
