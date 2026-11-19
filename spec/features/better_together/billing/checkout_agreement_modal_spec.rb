# frozen_string_literal: true

require 'rails_helper'

# The checkout review step reuses the shared agreement modal: the box is locked until the agreement
# has been opened and read to the end, exactly as on the sign-up form. See
# .claude/skills/agreement-mechanism/SKILL.md.
RSpec.describe 'Checkout uses the shared agreement modal', :js, :skip_host_setup, retry: 0 do # rubocop:disable RSpec/DescribeClass
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:cash_plan) do
    create(:better_together_billing_plan, :unlinked, processor: nil, accepted_payment_methods: %w[cash], billing_interval: 'one_time',
                                                     name: 'Garden plot', currency: 'USD', amount_cents: 2500)
  end
  let(:box) { '#billing-agreement-accept-one_time_purchase_agreement' }

  before do
    Current.platform = host_platform
    host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true,
                                                     settings: { 'instructions' => 'At the hall' })
    purchase_agreements_for(host_platform)
    capybara_login_as_platform_manager
    visit "/#{I18n.default_locale}/billing/checkout/new?plan_id=#{cash_plan.id}&payment_method=cash"
  end

  after { Current.platform = nil }

  def scroll_modal_to_end
    expect(page).to have_css('#agreementModal.show #agreement_modal_frame', text: 'Terms', wait: 10)
    page.execute_script(<<~JS)
      (function() {
        const body = document.getElementById('agreement_modal_frame').closest('.modal-body');
        body.scrollTop = body.scrollHeight;
        body.dispatchEvent(new Event('scroll', { bubbles: true }));
      })();
    JS
  end

  it 'locks the box until the agreement has been read in the modal' do
    expect(page).to have_css("#{box}.agreement-checkbox[data-agreement-identifier='one_time_purchase_agreement']")
    expect(page).to have_css('#billing-agreement-view-one_time_purchase_agreement.agreement-modal-link')

    find('#billing-agreement-view-one_time_purchase_agreement').click
    expect(page).to have_css('#agreementModal.show', wait: 10)
    scroll_modal_to_end

    expect(page).to have_css("#{box}[data-better-together-agreement-enabled='true']", visible: :all, wait: 10)
    expect(find(box, visible: :all)).not_to be_disabled
  end
end
