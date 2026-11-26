# frozen_string_literal: true

require 'rails_helper'

# Screenshots for the billing page's locked extras: add-ons for sale that need a plan the person does not hold yet.
RSpec.describe 'Billing locked add-ons', :as_user, :js, type: :feature do # rubocop:disable RSpec/DescribeClass
  include_context 'with subscription fixtures'
  include_context 'with billing switched on'
  include_context 'with billing extras'

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    create_extra(amount_cents: 700, name: 'Conference lunch', needs: :any_plan)
  end

  after { Current.platform = nil }

  it 'captures an extra that needs a plan first, with the reason' do
    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_hub_locked_add_ons',
      device: :both,
      metadata: { locale: I18n.default_locale, role: 'user', feature_set: 'billing_purchase_requirements',
                  flow: 'billing_hub_locked_add_ons', source_spec: self.class.metadata[:file_path] },
      callouts: [{ id: 'locked', selector: '#billing-hub-locked-add-ons', title: 'Extras you can unlock',
                   bullets: ['An extra for sale that needs something first, with the reason beside it.'] }],
      narrative: {
        title: 'Locked extras on the billing page',
        audience: %w[end_user],
        journey_step: 'As a visitor without a plan, I see which extras exist and what I need before I can buy them.',
        callouts: [{ id: 'locked', title: 'Locked extra', description: 'The reason replaces the buy button.' }],
        accessibility_notes: 'The section is labelled by its heading; the reason is plain text beside the name.'
      }
    ) do
      capybara_login_as_user
      visit "/#{I18n.default_locale}/billing"
      expect(page).to have_css('#billing-hub-locked-add-ons')
      page.execute_script("document.querySelector('#billing-hub-locked-add-ons').scrollIntoView({block: 'center'})")
    end
  end
end
