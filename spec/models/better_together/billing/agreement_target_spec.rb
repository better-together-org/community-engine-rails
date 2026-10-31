# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::AgreementTarget do
  it 'registers the models that can ask for terms of their own' do
    expect(described_class.model_names).to include('BetterTogether::Billing::Plan', 'BetterTogether::Community', 'BetterTogether::Person')
  end

  it 'does not register anything that has not included it' do
    expect(described_class.model_names).not_to include('BetterTogether::Platform', 'Kernel')
  end
end
