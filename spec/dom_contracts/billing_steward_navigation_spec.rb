# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the billing links in the host menu: asserts the stable markers that documentation
# screenshots (spec/docs_screenshots/better_together/billing_steward_navigation_spec.rb) target.
RSpec.describe 'Billing steward navigation DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with clean billing processors'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let(:links) do
    { 'billing-plans' => 'plans', 'billing-processor-settings' => 'processor_settings', 'billing-sales' => 'sales',
      'billing-subscribers' => 'subscribers', 'billing-tax-registrations' => 'tax_registrations',
      'billing-agreement-requirements' => 'agreement_requirements', 'billing-promotions' => 'promotions',
      'billing-credit-accounts' => 'credit_accounts', 'billing-allowances' => 'allowances' }
  end

  before do
    BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new(capabilities: %i[plan_sync lookups]) })
    Current.platform = BetterTogether::Platform.find_by(host: true)
    BetterTogether::NavigationBuilder.build_host
    Current.platform = nil
  end

  it 'marks every billing entry in the host menu with its identifier and target' do
    get "/#{locale}/billing/plans"

    page = Nokogiri::HTML(response.body)
    links.each do |identifier, path|
      link = page.at_css(%(#host-nav-item a.dropdown-item[data-identifier="#{identifier}"]))
      expect(link).to be_present, "expected a host menu entry for #{identifier}"
      expect(URI.parse(link['href']).path).to eq("/#{locale}/billing/#{path}")
    end
  end
end
