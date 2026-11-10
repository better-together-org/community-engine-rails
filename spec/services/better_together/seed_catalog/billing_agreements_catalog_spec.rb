# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::SeedCatalog::BillingAgreementsCatalog do
  include_context 'with clean billing processors'
  include_context 'with builtin billing processors'

  let!(:host_platform) { configure_host_platform }

  # The host platform comes with them already (the agreement builder plants them); start from none.
  before do
    host_platform.billing_agreement_requirements.destroy_all
    BetterTogether::Agreement.where(platform: host_platform,
                                    identifier: %w[subscription_agreement one_time_purchase_agreement offline_payment_terms]).destroy_all
  end

  it 'is registered beside the geography and tax catalogs' do
    expect(BetterTogether::SeedCatalog::Registry.find(:billing_agreements)).to eq(described_class)
  end

  it 'has one category, the purchase agreements, and needs nothing planted first', :aggregate_failures do
    expect(described_class.categories.pluck(:key)).to eq([:billing_purchase_agreements])
    expect(described_class.missing_prerequisites(:billing_purchase_agreements)).to eq([])
    expect(described_class.category(:billing_purchase_agreements)[:label]).to eq('Purchase agreements')
  end

  it 'plants the agreements as drafts on the host platform once, and reports them planted', :aggregate_failures do
    expect(described_class.planted?(:billing_purchase_agreements)).to be(false)

    expect(described_class.plant(:billing_purchase_agreements)).to be(true)

    expect(described_class.planted?(:billing_purchase_agreements)).to be(true)
    expect(BetterTogether::Agreement.where(identifier: %w[subscription_agreement one_time_purchase_agreement offline_payment_terms],
                                           lifecycle_state: 'draft').count).to eq(3)
    expect { described_class.plant(:billing_purchase_agreements) }.not_to(change(BetterTogether::Agreement, :count))
  end

  it 'plants everything with Plant All and refuses a category it does not hold', :aggregate_failures do
    expect(described_class.plant(:nonsense)).to be(false)

    described_class.plant_all

    expect(described_class.planted?(:billing_purchase_agreements)).to be(true)
  end
end
