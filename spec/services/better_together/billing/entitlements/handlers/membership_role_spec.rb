# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Entitlements::Handlers::MembershipRole do
  include_context 'with entitlement fixtures'

  let(:handler_class) { described_class }

  def handler(parameters) = described_class.new(parameters, platform: host_platform)

  def platform_params(role = supporter_role) = { 'joinable' => 'platform', 'role' => role.identifier }

  describe 'its parameters' do
    it 'accept an unprivileged platform role' do
      expect(handler(platform_params).errors).to be_empty
    end

    it 'accept an unprivileged role in one of the platform\'s communities' do
      params = { 'joinable' => 'community', 'community_id' => community.id, 'role' => member_role.identifier }

      expect(handler(params).errors).to be_empty
    end

    it 'refuse a role that can manage things' do
      expect(handler(platform_params(manager_role)).errors).to eq([:role_privileged])
    end

    it 'refuse a role that does not exist, a place that is not allowed, and a community that is not this platform\'s' do
      expect(handler({ 'joinable' => 'platform', 'role' => 'nope' }).errors).to eq([:role_unknown])
      expect(handler({ 'joinable' => 'elsewhere', 'role' => supporter_role.identifier }).errors).to include(:joinable_unknown)
      foreign = create(:better_together_community, platform: create(:better_together_platform))
      params = { 'joinable' => 'community', 'community_id' => foreign.id, 'role' => member_role.identifier }
      expect(handler(params).errors).to include(:community_unknown)
    end

    it 'refuse a role of the other kind of place' do
      params = { 'joinable' => 'community', 'community_id' => community.id, 'role' => supporter_role.identifier }

      expect(handler(params).errors).to include(:role_unknown)
    end

    it 'name the grant the same way every time' do
      expect(handler(platform_params).key).to eq(described_class.new(platform_params, platform: host_platform).key)
      expect(handler(platform_params).key).to start_with('membership_role:platform:')
    end

    it 'are for people only' do
      expect(handler(platform_params).applies_to?(buyer)).to be(true)
      expect(handler(platform_params).applies_to?(community)).to be(false)
    end
  end

  describe 'applying and releasing' do
    let(:entitlement) { make_entitlement }

    it 'makes an active membership, owned by the entitlement' do
      applied = handler(platform_params).apply(entitlement)

      expect(applied.owned).to be(true)
      expect(applied.record).to have_attributes(member: buyer, joinable: host_platform, role: supporter_role, status: 'active')
    end

    it 'makes a membership in a community, with the platform given explicitly (a job has no current platform)' do
      Current.platform = nil
      params = { 'joinable' => 'community', 'community_id' => community.id, 'role' => member_role.identifier }

      applied = handler(params).apply(entitlement)

      expect(applied.record).to have_attributes(class: BetterTogether::PersonCommunityMembership, joinable: community,
                                                platform_id: host_platform.id)
    end

    it 'does not tell the person they were added, or removed' do
      entitlement
      clear_enqueued_jobs
      ActionMailer::Base.deliveries.clear
      grant = nil
      expect { grant = handler(platform_params).apply(entitlement) }.not_to have_enqueued_job(Noticed::EventJob)
      applied = entitlement.grants.create!(platform_id: host_platform.id, grant_key: 'k', kind: 'membership_role', parameters: platform_params,
                                           applied: grant.record, owned: true)

      expect { handler(platform_params).release(applied) }.not_to have_enqueued_job(Noticed::EventJob)
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it 'expires the person\'s permission cache when it makes or removes a membership' do
      allow(BetterTogether::Person).to receive(:expire_permission_cache_for_ids).and_call_original

      applied = handler(platform_params).apply(entitlement)
      expect(BetterTogether::Person).to have_received(:expire_permission_cache_for_ids).with([buyer.id]).at_least(:once)

      grant = entitlement.grants.create!(platform_id: host_platform.id, grant_key: 'k', kind: 'membership_role', parameters: platform_params,
                                         applied: applied.record, owned: true)
      handler(platform_params).release(grant)
      expect(platform_membership(buyer)).to be_nil
    end

    it 'adopts a membership the person already has, and never removes it' do
      existing = create(:better_together_person_platform_membership, member: buyer, joinable: host_platform, role: supporter_role,
                                                                     status: 'active')

      applied = handler(platform_params).apply(entitlement)
      expect(applied).to have_attributes(owned: false, record: existing)

      grant = entitlement.grants.create!(platform_id: host_platform.id, grant_key: 'k', kind: 'membership_role', parameters: platform_params,
                                         applied: existing, owned: false)
      handler(platform_params).release(grant)

      expect(existing.reload).to be_persisted
    end
  end
end
