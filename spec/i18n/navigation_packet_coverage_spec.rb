# frozen_string_literal: true

require 'rails_helper'

# A route name nobody can reach from the navigation is easy to forget. Every name in
# NavigationItem.route_names needs an item in the default navigation packet (which the
# better_together:navigation:ensure task adds to existing platforms), or a reason to be listed here.
RSpec.describe 'Navigation packet covers the route names' do # rubocop:disable RSpec/DescribeClass
  # Member-facing billing pages are reached from the billing hub, not the steward menus.
  let(:member_billing_routes) do
    %w[
      billing_billing_addresses_url billing_catalog_url billing_entitlements_url billing_hosting_plan_url
      billing_hub_url billing_notification_preferences_url billing_orders_url billing_subscriptions_url
    ]
  end
  # Not yet given a menu entry. Remove a name from here when its item is added to the packet.
  let(:not_yet_in_packet) do
    %w[
      agreements_url calendars_url calls_for_interest_url content_blocks_url geography_continents_url
      geography_countries_url geography_maps_url geography_regions_url geography_settlements_url
      geography_states_url joatu_offers_url joatu_requests_url platform_connections_url reports_url
      safety_cases_url users_url
    ]
  end

  let(:seeded_routes) do
    path = BetterTogether::Engine.root.join('config/seeds/better_together/navigation/records/navigation_items.yml')
    YAML.safe_load_file(path).fetch('records').filter_map { |record| record.dig('attributes', 'route_name') }
  end

  it 'has a seeded item for every route name, except the listed ones' do
    missing = BetterTogether::NavigationItem.route_name_urls - seeded_routes - member_billing_routes - not_yet_in_packet

    expect(missing).to be_empty,
                       "Add a packet item (and a migration running better_together:navigation:ensure) for: #{missing.join(', ')}"
  end

  it 'does not list a name that is seeded or no longer exists' do
    stale = (member_billing_routes + not_yet_in_packet).select do |url|
      seeded_routes.include?(url) || BetterTogether::NavigationItem.route_name_urls.exclude?(url)
    end

    expect(stale).to be_empty, "Remove from the exclusion lists: #{stale.join(', ')}"
  end
end
