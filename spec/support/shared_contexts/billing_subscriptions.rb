# frozen_string_literal: true

# A monthly plan paid for with cash or store credit, both switched on for the host platform, and the helpers
# to start a subscription and to move time. Subscription orders are followed up by a job after they are paid,
# so the helpers run it.
RSpec.shared_context 'with subscription fixtures' do
  include_context 'with offline payment fixtures'

  let(:sub_plan) do
    create(:better_together_billing_plan, processor: nil, processor_price_id: nil, processor_product_id: nil, billing_interval: 'month',
                                          amount_cents: 3000, currency: 'USD', accepted_payment_methods: %w[cash store_credit],
                                          grace_days: 7, renewal_lead_days: 14)
  end
  let(:credit) { BetterTogether::Billing::Credit }
  let(:start_time) { Time.utc(2027, 1, 31, 15, 0, 0) }

  before do
    host_platform.update_columns(time_zone: 'UTC') # rubocop:disable Rails/SkipsModelValidations
    host_platform.billing_processor_settings.create!(processor: 'store_credit', enabled: true, acknowledge: true,
                                                     purposes: %w[subscription one_time ticket exchange])
    enable_offline('cash', purposes: %w[subscription one_time])
  end

  def give_credit(cents, holder: buyer)
    credit::Grant.call(platform: host_platform, holder:, amount_cents: cents, currency: 'USD', origin: 'steward_grant', actor: steward,
                       idempotency_key: SecureRandom.uuid)
  end

  # Starts a subscription to `sub_plan`, paid at `start_time` by `method`.
  def start_subscription(method: 'cash', at: start_time, plan: sub_plan, payer: buyer, **attrs)
    travel_to(at) do
      give_credit(plan.amount_cents, holder: payer) if method == 'store_credit'
      order = place_order(buyer: payer, purpose: 'subscription', payment_method: method, lines: [{ purchasable: plan }], **attrs)
      pay_manually(order) unless method == 'store_credit'
      follow_up
      order.reload.subject
    end
  end

  # The platform changes the subscription agreement, so everyone who accepted it must accept it again.
  def change_subscription_agreement
    BetterTogether::Agreement.find_by!(platform: host_platform, identifier: 'subscription_agreement').update!(title: 'Changed terms')
  end

  def pay_manually(order, received_on: nil)
    transition.receive(order.offline_payments.first, by: steward, received_on:)
    order.reload
  end

  # Runs the jobs that follow a payment (starting or renewing a subscription).
  # A job can queue another (a paid order starts a subscription, which queues what it gives), so go until none is left.
  def follow_up(&block)
    return perform_enqueued_jobs(&block) if block

    4.times { perform_enqueued_jobs }
  end

  def generate_renewal(term, at:)
    travel_to(at) { BetterTogether::Billing::Subscriptions::GenerateRenewal.call(term: term.reload) }
  end

  def advance(term, at:)
    travel_to(at) { BetterTogether::Billing::Subscriptions::Advance.call(term: term.reload) }
    term.reload.pay_subscription
  end

  def pay_renewal(term, at:, received_on: nil)
    travel_to(at) do
      order = term.reload.periods.last.order
      pay_manually(order, received_on:)
      follow_up
    end
    term.reload
  end
end

# A plan that includes things, and the helpers to give it grants and to look at what a person has.
RSpec.shared_context 'with entitlement fixtures' do
  include_context 'with subscription fixtures'

  let(:entitlements) { BetterTogether::Billing::Entitlements }
  let(:supporter_role) { create(:better_together_role, :platform_role, identifier: "supporter-#{SecureRandom.hex(3)}", name: 'Supporter') }
  let(:member_role) { create(:better_together_role, :community_role, identifier: "paid-member-#{SecureRandom.hex(3)}", name: 'Paid member') }
  let(:manager_role) do
    create(:better_together_role, :platform_role, identifier: "boss-#{SecureRandom.hex(3)}", name: 'Boss').tap do |role|
      role.resource_permissions << (BetterTogether::ResourcePermission.find_by(identifier: 'manage_platform') ||
                                    create(:better_together_resource_permission, identifier: 'manage_platform', action: 'manage',
                                                                                 resource_type: 'BetterTogether::Platform', target: 'platform'))
    end
  end
  let(:community) { create(:better_together_community, platform: host_platform) }

  before { BetterTogether::Quotas::Allowances.register('billing_entitlements', BetterTogether::Billing::Entitlements::QuotaAllowances) }

  def add_grant(kind, parameters, plan: sub_plan)
    plan.plan_grants.create!(platform_id: plan.platform_id, kind:, parameters:, position: plan.plan_grants.count)
  end

  def role_grant(role = supporter_role) = add_grant('membership_role', { 'joinable' => 'platform', 'role' => role.identifier })
  def feature_grant(key: 'device_permissions') = add_grant('feature_access', { 'feature_key' => key, 'access_level' => 'beta' })
  def quota_grant(amount: 5_000, type: 'media_storage') = add_grant('quota_allowance', { 'quota_type' => type, 'amount' => amount })

  # A stored entitlement for `beneficiary`, made by hand (no grants applied), on a real subscription.
  def make_entitlement(beneficiary: buyer, plan: sub_plan)
    term = start_subscription(payer: create(:better_together_person))
    host_platform.billing_entitlements.create!(plan:, beneficiary:, pay_subscription: term.pay_subscription, starts_at: Time.current)
  end

  def entitlement_for(term) = host_platform.billing_entitlements.find_by(pay_subscription_id: term.pay_subscription_id)

  def platform_membership(person, role = supporter_role)
    BetterTogether::PersonPlatformMembership.find_by(member_id: person.id, joinable_id: host_platform.id, role_id: role.id)
  end

  def sync(term) = entitlements::Sync.subscription(term.reload)
end
