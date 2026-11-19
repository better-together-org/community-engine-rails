# frozen_string_literal: true

require 'rails_helper'

# The billing steward pages are reachable from the host menu, not only by typing the URL.
# They show only where billing is on for the platform and the person may manage it.
RSpec.describe 'Billing steward navigation' do # rubocop:disable RSpec/DescribeClass
  include_context 'with clean billing processors'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:steward_paths) do
    %w[plans processor_settings sales subscribers tax_registrations agreement_requirements promotions credit_accounts allowances]
      .map { |name| "/#{locale}/billing/#{name}" }
  end

  before do
    BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new(capabilities: %i[plan_sync lookups]) })
    Current.platform = host_platform
    BetterTogether::NavigationBuilder.build_host
    Current.platform = nil
  end

  def host_menu_hrefs
    Nokogiri::HTML(response.body).css('a.dropdown-item').filter_map { |a| URI.parse(a['href'].to_s).path }
  end

  context 'with a platform manager', :as_platform_manager do
    it 'lists every steward page in the host menu for a steward when billing is on' do
      get "/#{locale}/billing/plans"

      expect(response).to have_http_status(:ok)
      steward_paths.each { |path| expect(host_menu_hrefs).to include(path) }
    end

    it 'lists none of them while billing is off' do
      allow(BetterTogether::Billing::Configuration).to receive(:requested?).and_return(false)

      get "/#{locale}/host"

      steward_paths.each { |path| expect(host_menu_hrefs).not_to include(path) }
    end
  end

  context 'with a signed-in person who may not manage billing', :as_user do
    it 'lists none of them' do
      get "/#{locale}/host"

      steward_paths.each { |path| expect(host_menu_hrefs).not_to include(path) }
    end
  end
end
