# frozen_string_literal: true

require 'rails_helper'

# All billing routes live in config/routes/billing.rb, drawn from config/routes.rb
# with `draw :billing`, the same way config/routes/api.rb is.
RSpec.describe 'Billing routes' do # rubocop:disable RSpec/DescribeClass
  let(:routes_file) { BetterTogether::Engine.root.join('config/routes.rb').read }
  let(:billing_path) { BetterTogether::Engine.root.join('config/routes/billing.rb') }
  let(:processors) { [Pay::Stripe, Pay::Braintree, Pay::PaddleBilling, Pay::PaddleClassic, Pay::LemonSqueezy] }

  # Draws the billing routes file into a scratch route set, so the processor
  # state can be changed without redrawing the application's routes.
  def draw_billing_routes
    source = billing_path.read
    file = billing_path.to_s
    ActionDispatch::Routing::RouteSet.new.tap { |set| set.draw { instance_eval(source, file) } }
  end

  def pay_mount(route_set) = route_set.routes.find { |route| route.path.spec.to_s == '/pay' }

  def request_for(path) = ActionDispatch::Request.new(Rack::MockRequest.env_for(path))

  it 'keeps billing routes out of routes.rb except the draw line' do
    billing_lines = routes_file.lines.grep(/billing|Pay::Engine/i).map(&:strip).reject { |line| line.start_with?('#') }

    expect(billing_lines).to eq(['draw :billing'])
  end

  it 'draws the billing routes before the localized block and its catch-all' do
    expect(routes_file.index('draw :billing')).to be < routes_file.index("scope ':locale'")
    expect(routes_file.index("scope ':locale'")).to be < routes_file.index("get '*path', to: 'pages#show'")
  end

  describe 'the Pay engine mount' do
    it 'is absent when no processor gem is installed, so nothing is exposed' do
      processors.each { |processor| allow(processor).to receive(:enabled?).and_return(false) }

      expect(pay_mount(draw_billing_routes)).to be_nil
    end

    context 'when a processor gem is installed' do
      let(:mount) { pay_mount(draw_billing_routes) }

      before { allow(Pay::Stripe).to receive(:enabled?).and_return(true) }

      it 'is mounted at /pay' do
        expect(mount).to be_present
        expect(mount.app.app).to eq(Pay::Engine)
      end

      it 'reaches only the webhook endpoints, not Pay payment confirmation pages' do
        expect(mount.app.matches?(request_for('/pay/webhooks/stripe'))).to be(true)
        expect(mount.app.matches?(request_for('/pay/payments/pi_123'))).to be(false)
      end
    end
  end

  describe 'the plan routes' do
    it 'live under /:locale/billing, not under the host dashboard' do
      expect(get: '/en/billing/plans').to route_to(controller: 'better_together/billing/plans', action: 'index', locale: 'en')
      expect(get: '/en/billing/plans/abc').to route_to(controller: 'better_together/billing/plans', action: 'show', locale: 'en', id: 'abc')
      expect(get: '/en/host/billing/plans').not_to route_to(controller: 'better_together/billing/plans', action: 'index', locale: 'en')
    end

    it 'resolves an HTML GET to the plans controller, not the pages catch-all' do
      expect(get: '/en/billing/plans/new').to route_to(controller: 'better_together/billing/plans', action: 'new', locale: 'en')
    end

    it 'has member routes to retry a sync and to read the processor snapshot' do
      expect(post: '/en/billing/plans/abc/sync').to route_to(controller: 'better_together/billing/plans', action: 'sync', locale: 'en',
                                                             id: 'abc')
      expect(get: '/en/billing/plans/abc/snapshot').to route_to(controller: 'better_together/billing/plans', action: 'snapshot', locale: 'en',
                                                                id: 'abc')
    end

    it 'has no destroy route' do
      expect(delete: '/en/billing/plans/abc').not_to be_routable
    end

    it 'serves option lists from one index endpoint' do
      expect(get: '/en/billing/processor_options')
        .to route_to(controller: 'better_together/billing/processor_options', action: 'index', locale: 'en')
      expect(post: '/en/billing/processor_options').not_to be_routable
    end

    it 'is constrained to the available locales' do
      expect(get: '/zz/billing/plans').not_to route_to(controller: 'better_together/billing/plans', action: 'index', locale: 'zz')
    end

    it 'keeps the helper names the navigation items call' do
      expect(BetterTogether::Engine.routes.url_helpers).to respond_to(:billing_plans_url, :billing_plans_path,
                                                                      :billing_processor_settings_url)
    end

    it 'has read-only order pages for the buyer and for stewards' do
      expect(get: '/en/billing/orders').to route_to(controller: 'better_together/billing/orders', action: 'index', locale: 'en')
      expect(get: '/en/billing/orders/abc').to route_to(controller: 'better_together/billing/orders', action: 'show', locale: 'en', id: 'abc')
      expect(get: '/en/billing/sales').to route_to(controller: 'better_together/billing/sales', action: 'index', locale: 'en')
      expect(get: '/en/billing/sales/abc').to route_to(controller: 'better_together/billing/sales', action: 'show', locale: 'en', id: 'abc')
      [{ post: '/en/billing/orders' }, { patch: '/en/billing/orders/abc' }, { delete: '/en/billing/orders/abc' }, { post: '/en/billing/sales' }]
        .each { |verb_path| expect(verb_path).not_to be_routable }
    end

    it 'has one checkout, and steward-managed purchase terms that can be listed, added and removed only' do
      expect(get: '/en/billing/checkout/new').to route_to(controller: 'better_together/billing/checkouts', action: 'new', locale: 'en')
      expect(post: '/en/billing/checkout').to route_to(controller: 'better_together/billing/checkouts', action: 'create', locale: 'en')
      expect(get: '/en/billing/agreement_requirements').to route_to(controller: 'better_together/billing/agreement_requirements',
                                                                    action: 'index', locale: 'en')
      expect(post: '/en/billing/agreement_requirements').to route_to(controller: 'better_together/billing/agreement_requirements',
                                                                     action: 'create', locale: 'en')
      expect(delete: '/en/billing/agreement_requirements/abc')
        .to route_to(controller: 'better_together/billing/agreement_requirements', action: 'destroy', locale: 'en', id: 'abc')
      expect(patch: '/en/billing/agreement_requirements/abc').not_to be_routable
      # An unmatched GET falls through to the pages catch-all, never to a billing controller.
      expect(get: '/en/billing/checkout').not_to route_to(controller: 'better_together/billing/checkouts', action: 'show', locale: 'en')
      expect(get: '/en/billing/agreement_requirements/abc')
        .not_to route_to(controller: 'better_together/billing/agreement_requirements', action: 'show', locale: 'en', id: 'abc')
    end

    it 'has payment method settings, addressed by method name, that can be listed, edited and updated only' do
      expect(get: '/en/billing/processor_settings')
        .to route_to(controller: 'better_together/billing/processor_settings', action: 'index', locale: 'en')
      expect(get: '/en/billing/processor_settings/cash/edit')
        .to route_to(controller: 'better_together/billing/processor_settings', action: 'edit', locale: 'en', id: 'cash')
      expect(patch: '/en/billing/processor_settings/cash')
        .to route_to(controller: 'better_together/billing/processor_settings', action: 'update', locale: 'en', id: 'cash')
      expect(post: '/en/billing/processor_settings').not_to be_routable
      expect(delete: '/en/billing/processor_settings/cash').not_to be_routable
    end
  end
end
