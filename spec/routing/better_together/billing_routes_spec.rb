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
end
