# spec/support/engine_routes.rb

RSpec.shared_context 'engine routes for BetterTogether', shared_context: :metadata do
  before do
    @routes = BetterTogether::Engine.routes
  end
end
