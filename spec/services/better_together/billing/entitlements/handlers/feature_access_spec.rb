# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Entitlements::Handlers::FeatureAccess do
  include_context 'with entitlement fixtures'

  let(:parameters) { { 'feature_key' => 'device_permissions', 'access_level' => 'beta' } }
  let(:handler) { described_class.new(parameters, platform: host_platform) }
  let(:entitlement) { make_entitlement }

  it 'accepts a feature the platform has and a level that exists, and refuses anything else' do
    expect(handler.errors).to be_empty
    expect(described_class.new({ 'feature_key' => 'nonsense', 'access_level' => 'beta' },
                               platform: host_platform).errors).to eq([:feature_unknown])
    expect(described_class.new(parameters.merge('access_level' => 'gold'), platform: host_platform).errors).to eq([:level_unknown])
  end

  it 'is for people only' do
    expect(handler.applies_to?(buyer)).to be(true)
    expect(handler.applies_to?(community)).to be(false)
  end

  it 'gives a person access, owned by the entitlement, and revokes only that' do
    applied = handler.apply(entitlement)

    expect(applied).to have_attributes(owned: true)
    expect(applied.record).to have_attributes(person: buyer, feature_key: 'device_permissions', access_level: 'beta',
                                              platform_id: host_platform.id)
    grant = entitlement.grants.create!(platform_id: host_platform.id, grant_key: handler.key, kind: 'feature_access', parameters:,
                                       applied: applied.record, owned: true)

    handler.release(grant)

    expect(applied.record.reload).to have_attributes(revoked_at: be_present)
  end

  it 'adopts access the person already has, and never revokes it' do
    existing = create(:better_together_feature_access_grant, person: buyer, platform: host_platform, feature_key: 'device_permissions',
                                                             expires_at: nil)

    applied = handler.apply(entitlement)
    grant = entitlement.grants.create!(platform_id: host_platform.id, grant_key: handler.key, kind: 'feature_access', parameters:,
                                       applied: existing, owned: false)
    handler.release(grant)

    expect(applied).to have_attributes(owned: false, record: existing)
    expect(existing.reload.revoked_at).to be_nil
  end
end
