# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe NavigationItem, 'route name groups' do
    around do |example|
      names = described_class.route_names
      registered = described_class.registered_route_name_groups
      example.run
    ensure
      described_class.route_names = names
      described_class.registered_route_name_groups = registered
    end

    describe '.route_name_groups' do
      it 'keeps every route name in exactly one group' do
        listed = described_class.route_name_groups.values.flat_map(&:keys)

        expect(listed).to match_array(described_class.route_names.keys)
      end

      it 'groups the billing screens apart from the host dashboard' do
        groups = described_class.route_name_groups

        expect(groups[:billing_management]).to include(billing_plans: 'billing_plans_url')
        expect(groups[:host_dashboard]).not_to have_key(:billing_plans)
      end

      it 'lists no empty group' do
        expect(described_class.route_name_groups.values).to all(be_present)
      end
    end

    describe 'the built-in route list' do
      it 'only names routes the engine defines' do
        helpers = BetterTogether::Engine.routes.url_helpers
        unknown = described_class.route_name_urls.reject { |url| helpers.respond_to?(url) }

        expect(unknown).to be_empty
      end

      it 'is validated against the flat list, so a stored name keeps working' do
        item = build(:better_together_navigation_item, route_name: 'billing_plans_url', url: nil)

        expect(item).to be_valid
      end
    end

    describe '.register_route_names' do
      it 'adds names to a host app group and to the flat list' do
        described_class.register_route_names({ venues: 'venues_url' }, group: :venues)

        expect(described_class.route_name_groups[:venues]).to eq(venues: 'venues_url')
        expect(described_class.route_name_urls).to include('venues_url')
      end

      it 'accepts a list of names' do
        described_class.register_route_names(%i[tours], group: :venues)

        expect(described_class.route_names[:tours]).to eq('tours_url')
      end

      it 'files names merged straight into route_names under :other, as host apps do today' do
        described_class.route_names = described_class.route_names.merge(artists: 'artists_url')

        expect(described_class.route_name_groups[:other]).to eq(artists: 'artists_url')
      end

      it 'puts :other last' do
        described_class.register_route_names({ venues: 'venues_url' }, group: :venues)
        described_class.route_names = described_class.route_names.merge(artists: 'artists_url')

        expect(described_class.route_name_groups.keys.last).to eq(:other)
      end

      it 'still validates a route name a host app registered' do
        described_class.register_route_names({ venues: 'venues_url' }, group: :venues)
        item = build(:better_together_navigation_item, route_name: 'venues_url', url: nil)

        expect(item).to be_valid
      end
    end

    describe 'route availability' do
      let(:platform) { instance_double(BetterTogether::Platform, host?: true) }

      it 'gates the setup screens on configuration, as their controllers do' do
        allow(BetterTogether::Billing).to receive_messages(configurable?: true, enabled?: false)

        gates = %w[billing_tax_registrations_url billing_agreement_requirements_url billing_processor_settings_url]

        expect(gates.map { |url| described_class::ROUTE_AVAILABILITY[url].call(platform) }).to all(be(true))
      end

      it 'gates the buyer screens on billing being enabled' do
        allow(BetterTogether::Billing).to receive(:enabled?).with(platform).and_return(false)

        expect(described_class::ROUTE_AVAILABILITY['billing_hub_url'].call(platform)).to be(false)
      end
    end
  end
end
