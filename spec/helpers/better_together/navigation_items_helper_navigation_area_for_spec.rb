# frozen_string_literal: true

require 'rails_helper'

# Navigation areas are looked up by identifier. With several platforms the lookup must stay on the
# current platform, fall back to the host platform, and never pick another tenant's area.
RSpec.describe BetterTogether::NavigationItemsHelper, '#navigation_area_for' do
  let!(:host_platform) { configure_host_platform }
  let(:tenant) { create(:better_together_platform, :public) }
  let(:other_tenant) { create(:better_together_platform, :public) }

  def area_for(platform, identifier: 'platform-header')
    BetterTogether::NavigationArea.find_by(platform:, identifier:) ||
      create(:better_together_navigation_area, platform:, identifier:, visible: true, name: "#{platform.id} #{identifier}")
  end

  it 'returns the current platform area when it has one' do
    own = area_for(tenant)
    area_for(host_platform)

    Current.set(platform: tenant) { expect(helper.navigation_area_for('platform-header')).to eq(own) }
  end

  it 'falls back to the host platform area when the tenant has none' do
    host_area = area_for(host_platform)
    area_for(other_tenant)

    Current.set(platform: tenant) { expect(helper.navigation_area_for('platform-header')).to eq(host_area) }
  end

  it 'never returns another tenant area when neither current nor host has one' do
    area_for(other_tenant, identifier: 'tenant-only-area')

    Current.set(platform: tenant) { expect(helper.navigation_area_for('tenant-only-area')).to be_nil }
  end
end
