# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformRecord do
  it 'is an abstract class' do
    expect(described_class.abstract_class).to be true
  end

  it 'inherits from ApplicationRecord' do
    expect(described_class.superclass).to eq(BetterTogether::ApplicationRecord)
  end

  it 'includes PlatformScoped' do
    expect(described_class.ancestors).to include(BetterTogether::PlatformScoped)
  end
end
