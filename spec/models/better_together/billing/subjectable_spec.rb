# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Subjectable do
  it 'registers a model by name when it opts in' do
    expect(described_class.model_names).to include('BetterTogether::Platform')
  end

  it 'does not register anything that has not included it' do
    expect(described_class.model_names).not_to include('BetterTogether::Person')
  end
end
