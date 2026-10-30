# frozen_string_literal: true

require 'rails_helper'

# A navigation item that points at the billing plans is shown only where that page
# exists, so a platform that has not set billing up never shows a link that answers 404.
RSpec.describe BetterTogether::NavigationItem, '#visible_to?' do
  # The billing plans link: shown only where that page exists, so a platform that has not set
  # billing up never shows a link that answers 404.
  include_context 'with clean billing processors'
  include_context 'with billing switched on'

  let!(:host_platform) { configure_host_platform }
  let(:other_platform) { create(:better_together_platform) }
  let(:item) do
    build(:better_together_navigation_item, route_name: 'billing_plans_url', privacy: 'public', visible: true, item_type: 'link',
                                            linkable_type: nil, linkable_id: nil, url: nil)
  end

  before do
    BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new(capabilities: %i[plan_sync]) })
  end

  it 'is a valid route name for an item' do
    expect(described_class.route_name_urls).to include('billing_plans_url')
  end

  it 'is visible on the platform that has billing set up' do
    expect(item.visible_to?(nil, platform: host_platform)).to be(true)
  end

  it 'is hidden on a platform without a processor context' do
    expect(item.visible_to?(nil, platform: other_platform)).to be(false)
  end

  it 'is hidden while billing is switched off' do
    allow(BetterTogether::Billing::Configuration).to receive(:requested?).and_return(false)

    expect(item.visible_to?(nil, platform: host_platform)).to be(false)
  end

  it 'is hidden when no processor is installed' do
    BetterTogether.clear_adapters!(BetterTogether::Billing::ADAPTER_GROUP)

    expect(item.visible_to?(nil, platform: host_platform)).to be(false)
  end

  describe 'the payment methods link' do
    let(:methods_item) do
      build(:better_together_navigation_item, route_name: 'billing_processor_settings_url', privacy: 'public', visible: true,
                                              item_type: 'link', linkable_type: nil, linkable_id: nil, url: nil)
    end

    it 'is a valid route name' do
      expect(described_class.route_name_urls).to include('billing_processor_settings_url')
    end

    it 'is visible before any method is on, so the first one can be turned on' do
      BetterTogether.clear_adapters!(BetterTogether::Billing::ADAPTER_GROUP)
      BetterTogether::Billing.register_builtin_processors!

      expect(BetterTogether::Billing.enabled?(host_platform)).to be(false)
      expect(methods_item.visible_to?(nil, platform: host_platform)).to be(true)
    end

    it 'is hidden while billing is not switched on' do
      BetterTogether::Billing.register_builtin_processors!
      allow(BetterTogether::Billing::Configuration).to receive(:requested?).and_return(false)

      expect(methods_item.visible_to?(nil, platform: host_platform)).to be(false)
    end
  end

  describe 'the sales link' do
    let(:sales_item) do
      build(:better_together_navigation_item, route_name: 'billing_sales_url', privacy: 'public', visible: true,
                                              item_type: 'link', linkable_type: nil, linkable_id: nil, url: nil)
    end

    it 'is a valid route name, and visible only where billing is enabled' do
      expect(described_class.route_name_urls).to include('billing_sales_url')
      expect(sales_item.visible_to?(nil, platform: host_platform)).to be(true)
      expect(sales_item.visible_to?(nil, platform: other_platform)).to be(false)
    end
  end

  it 'leaves every other route unaffected' do
    other = build(:better_together_navigation_item, route_name: 'pages_url', privacy: 'public', visible: true, item_type: 'link',
                                                    linkable_type: nil, linkable_id: nil, url: nil)

    expect(other.visible_to?(nil, platform: other_platform)).to be(true)
  end
end
