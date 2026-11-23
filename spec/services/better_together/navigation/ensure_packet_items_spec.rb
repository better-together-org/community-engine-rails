# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Navigation
    RSpec.describe EnsurePacketItems do
      let!(:area) do
        BetterTogether::NavigationArea.find_by(identifier: 'platform-host') ||
          create(:better_together_navigation_area, identifier: 'platform-host', slug: 'platform-host')
      end
      let!(:host_nav) do
        # Start from an empty area so the examples see only what the service adds.
        BetterTogether::NavigationItem.where(navigation_area: area).where.not(parent_id: nil).delete_all
        BetterTogether::NavigationItem.where(navigation_area: area).delete_all
        create(:better_together_navigation_item, navigation_area: area, identifier: 'host-nav', item_type: 'dropdown',
                                                 url: '#', protected: false)
      end

      def identifiers = BetterTogether::NavigationItem.where(navigation_area: area).pluck(:identifier)

      it 'reports without writing on a dry run' do
        expect { described_class.call(dry_run: true) }.not_to change(BetterTogether::NavigationItem, :count)
      end

      it 'adds the Billing menu and its children from the packet' do
        described_class.call
        billing = BetterTogether::NavigationItem.find_by(navigation_area: area, identifier: 'billing')

        expect(billing.children.pluck(:identifier)).to include('billing-plans', 'billing-dashboard')
      end

      it 'puts the host review pages under the Host menu' do
        described_class.call

        expect(host_nav.children.pluck(:identifier)).to include('host-dashboard-weather', 'host-dashboard-billing')
      end

      it 'is idempotent' do
        described_class.call

        expect(described_class.call).to be_empty
      end

      it 'leaves an item a steward already edited alone' do
        item = create(:better_together_navigation_item, navigation_area: area, parent: host_nav, protected: false,
                                                        identifier: 'host-dashboard-weather', title: 'My weather',
                                                        route_name: 'host_dashboard_weather_url')
        described_class.call

        expect(item.reload.title).to eq('My weather')
      end

      it 'moves a legacy billing item from the Host menu into the Billing menu' do
        legacy = create(:better_together_navigation_item, navigation_area: area, parent: host_nav, protected: false,
                                                          identifier: 'billing-plans', route_name: 'billing_plans_url')
        described_class.call

        expect(legacy.reload.parent.identifier).to eq('billing')
      end

      it 'does nothing for a platform without a host navigation area' do
        BetterTogether::NavigationItem.where(navigation_area: area).delete_all
        area.delete

        expect(described_class.call).to be_empty
      end
    end
  end
end
