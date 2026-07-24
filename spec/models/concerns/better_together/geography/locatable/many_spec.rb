# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Geography::Locatable::Many do
  describe '.included_in_models' do
    it 'returns exactly the models that include this concern' do
      models = described_class.included_in_models

      expect(models).to include(BetterTogether::Address, BetterTogether::Infrastructure::Building)
      expect(models).not_to include(BetterTogether::Geography::Settlement)
    end

    it 'does not include Event' do
      # Event's own geocoded_by is commented out (dead code) — nothing ever populates its
      # Space, so hierarchy resolution would always no-op. Event's geography placement is
      # reached through its Locatable::One location instead, not its own Space.
      expect(described_class.included_in_models).not_to include(BetterTogether::Event)
    end
  end

  describe 'LEVELS' do
    it 'maps every hierarchy level symbol to its class' do
      expect(described_class::LEVELS).to eq(
        settlement: BetterTogether::Geography::Settlement,
        region: BetterTogether::Geography::Region,
        state: BetterTogether::Geography::State,
        country: BetterTogether::Geography::Country,
        continent: BetterTogether::Geography::Continent
      )
    end

    it 'is frozen' do
      expect(described_class::LEVELS).to be_frozen
    end
  end

  describe 'hierarchy level readers' do
    subject(:address) { create(:better_together_address) }

    it 'returns nil for each level when no placement exists' do
      expect(address.settlement).to be_nil
      expect(address.region).to be_nil
      expect(address.state).to be_nil
      expect(address.country).to be_nil
      expect(address.continent).to be_nil
    end

    it 'returns the linked geography record when a placement exists' do
      settlement = create(:geography_settlement)
      BetterTogether::Geography::LocatableLocation.create!(
        locatable: address, location: settlement, resolution_method: 'polygon', resolved_at: Time.current
      )

      expect(address.settlement).to eq(settlement)
    end
  end

  describe '#resolve_geographic_hierarchy!' do
    subject(:address) { create(:better_together_address) }

    it 'enqueues HierarchyResolutionJob by default' do
      expect { address.resolve_geographic_hierarchy! }
        .to have_enqueued_job(BetterTogether::Geography::HierarchyResolutionJob).with(address)
    end

    it 'runs the job inline when async: false' do
      expect(BetterTogether::Geography::HierarchyResolutionJob).to receive(:perform_now).with(address) # rubocop:disable RSpec/MessageSpies

      address.resolve_geographic_hierarchy!(async: false)
    end
  end
end
