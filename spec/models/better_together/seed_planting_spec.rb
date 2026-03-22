# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::SeedPlanting do
  it 'tracks lifecycle transitions for federated tending' do
    planting = described_class.create!(
      planting_type: :federated_tending,
      metadata: { 'seed_count' => 2 },
      privacy: 'private'
    )

    planting.mark_started!
    planting.mark_completed!('processed_count' => 2)

    expect(planting).to be_completed
    expect(planting.result['processed_count']).to eq(2)
  end
end
