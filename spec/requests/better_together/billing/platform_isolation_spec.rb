# frozen_string_literal: true

# @hermetic
require 'rails_helper'

# A steward of one platform can never read another platform's billing records. The routes are
# derived from the engine's routing table (every billing index and show), so a new billing page
# that is not covered here fails the completeness example instead of slipping through.
RSpec.describe 'Billing platform isolation' do # rubocop:disable RSpec/DescribeClass
  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:locale) { 'en' }
  let(:password) { 'SecureTest123!@#' }
  let(:steward) { find_or_create_test_user("isolation-steward-#{SecureRandom.hex(4)}@example.test", password, :platform_manager) }
  let(:platform_b) { create(:better_together_platform) }
  let(:holder) { create(:better_together_person) }
  let!(:mine) { seed(host_platform, 'AAAA') }
  let!(:theirs) { seed(platform_b, 'BBBB') }

  # The record each id-bearing route is asked for, from the seeds of one platform.
  let(:record_for) do
    { 'better_together/billing/plans' => :plan, 'better_together/billing/catalog' => :plan,
      'better_together/billing/orders' => :order, 'better_together/billing/sales' => :order,
      'better_together/billing/credit_accounts' => :account, 'better_together/billing/subscriptions' => :term,
      'better_together/billing/subscribers' => :term, 'better_together/billing/events' => :event,
      'better_together/billing/sale_refund_requests' => :refund_request }
  end
  # What each list must show for the steward's own platform (proves the page is not simply empty).
  let(:listed) do
    { 'better_together/billing/plans' => :plan, 'better_together/billing/catalog' => :plan, 'better_together/billing/orders' => :order,
      'better_together/billing/sales' => :order, 'better_together/billing/credit_accounts' => :account,
      'better_together/billing/promotions' => :promotion, 'better_together/billing/subscribers' => :term,
      'better_together/billing/subscriptions' => :term, 'better_together/billing/offline_payments' => :offline,
      'better_together/billing/agreement_requirements' => :requirement, 'better_together/metrics/billing_reports' => :report }
  end

  before { sign_in steward }

  def seed(platform, tag) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    person = steward.person
    plan = create(:better_together_billing_plan, platform:, name: "Plan #{tag}", listed: true)
    order = create(:better_together_billing_order, :awaiting_payment, platform:, buyer: person, total_cents: 4500)
    payment = create(:better_together_billing_payment, order:, platform_id: platform.id, processor: 'cash', status: 'pending')
    offline = order.offline_payments.create!(platform_id: platform.id, payment:, processor: 'cash')
    credit = BetterTogether::Billing::Credit
    credit::Grant.call(platform:, holder:, amount_cents: 700, currency: 'USD', origin: 'steward_grant', actor: person,
                       idempotency_key: SecureRandom.uuid)
    promotion = platform.billing_promotions.create!(name: "Promo #{tag}", amount_cents: 1500, currency: 'USD', active: true,
                                                    code_digest: BetterTogether::Billing::Promotion.digest_for(SecureRandom.hex(10)))
    create(:better_together_billing_tax_registration, platform:, country_iso: 'CA')
    event = create(:better_together_billing_event, platform:, processing_status: 'failed', event_type: "fake.invoice.#{tag.downcase}")
    # Only isolation matters here, so the order need not be one that can really be refunded.
    refund_request = BetterTogether::Billing::RefundRequest.new(order:, platform_id: platform.id, requester: person, currency: order.currency,
                                                                reason: 'other', amount_cents: 1000, details: "Refund #{tag}")
    refund_request.save!(validate: false)
    { plan:, order:, offline:, promotion:, event:, refund_request:, term: seed_term(platform, plan),
      account: credit.find_account(platform:, holder:, currency: 'USD'),
      requirement: create(:better_together_billing_agreement_requirement, platform:),
      report: BetterTogether::Metrics::BillingReport.create!(platform:, creator: person, filters: { 'owner' => 'all', 'interval' => 'month' }) }
  end

  def seed_term(platform, plan)
    customer = steward.person.add_payment_processor(:local, platform:).api_record
    subscription = customer.subscribe(name: 'x', plan: 'x', current_period_start: Time.current, current_period_end: 1.month.from_now)
    platform.billing_subscription_terms.create!(pay_subscription: subscription, plan:, payment_method: 'cash', unit_amount_cents: 1,
                                                currency: 'USD', anchor_at: Time.current)
  end

  def billing_get_routes
    BetterTogether::Engine.routes.routes.select do |route|
      route.verb == 'GET' && %w[index show].include?(route.defaults[:action]) &&
        route.defaults[:controller].to_s.match?(%r{\Abetter_together/(billing|metrics/billing)})
    end
  end

  def path_for(route, id: nil)
    parts = route.required_parts - [:locale]
    return route.format(locale:) if parts.empty?

    route.format(locale:, parts.first => id)
  end

  def needs_id?(route) = (route.required_parts - [:locale]).any?

  # Everything that names a platform B record: its ids and the names we gave them. A page for one id
  # echoes that id back (the not-found page shows the path), so those checks use `labels_of` alone.
  def labels_of(seeds) = seeds.values.flat_map { |record| [record.try(:name), record.try(:number)] }.compact.map(&:to_s).reject(&:empty?)

  def markers_of(seeds) = seeds.values.map { |record| record.id.to_s } + labels_of(seeds)

  def controller_of(route) = route.defaults[:controller].to_s

  it 'finds the billing routes in the routing table', :aggregate_failures do
    controllers = billing_get_routes.map { |route| controller_of(route) }.uniq

    expect(controllers.size).to be >= 15
    expect(controllers).to include('better_together/billing/plans', 'better_together/billing/orders', 'better_together/billing/sales')
  end

  it 'covers every billing route that takes an id, so a new one cannot go untested' do
    unmapped = billing_get_routes.select { |route| needs_id?(route) }.map { |route| controller_of(route) }.uniq - record_for.keys

    expect(unmapped).to be_empty, "add a seeded record for: #{unmapped.join(', ')}"
  end

  it 'never lists another platform\'s records on any billing index or page', :aggregate_failures do
    billing_get_routes.reject { |route| needs_id?(route) }.each do |route|
      get path_for(route)

      expect(response.body).not_to include(*markers_of(theirs)), "#{route.path.spec} leaked platform B records"
    end
  end

  it 'lists the steward\'s own platform records where a page lists them', :aggregate_failures do
    billing_get_routes.reject { |route| needs_id?(route) }.each do |route|
      kind = listed[controller_of(route)]
      next unless kind

      get path_for(route)

      expect(response.body).to include(mine.fetch(kind).id.to_s), "#{route.path.spec} did not show the platform's own record"
    end
  end

  it 'answers not found, and shows nothing, for another platform\'s record on every billing show', :aggregate_failures do
    billing_get_routes.select { |route| needs_id?(route) }.each do |route|
      get path_for(route, id: theirs.fetch(record_for.fetch(controller_of(route))).id)

      expect(response).to have_http_status(:not_found), "#{route.path.spec} answered #{response.status} for platform B's record"
      expect(response.body).not_to include(*labels_of(theirs))
    end
  end

  it 'serves the same shows for the steward\'s own platform records', :aggregate_failures do
    billing_get_routes.select { |route| needs_id?(route) }.each do |route|
      get path_for(route, id: mine.fetch(record_for.fetch(controller_of(route))).id)

      expect(response).to have_http_status(:ok), "#{route.path.spec} answered #{response.status} for the platform's own record"
    end
  end
end
