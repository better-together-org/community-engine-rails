# frozen_string_literal: true

require 'rails_helper'

# Not run in normal CI (needs RUN_DOCS_SCREENSHOTS=1 and a browser):
#   bin/dc-run bash -c 'RUN_DOCS_SCREENSHOTS=1 bundle exec prspec spec/docs_screenshots/better_together/billing_plan_blocks_spec.rb'
# The identifiers it targets are locked by spec/dom_contracts/billing_plan_blocks_spec.rb.
RSpec.describe 'Documentation screenshots for the plan blocks', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  include_context 'with subscription fixtures'
  include_context 'with billing switched on'

  let(:free_attrs) { { processor: nil, processor_price_id: nil, processor_product_id: nil, amount_cents: 0, accepted_payment_methods: [] } }
  let(:dom_id) { ->(*args) { ActionView::RecordIdentifier.dom_id(*args) } }
  let(:content_page) { create(:better_together_page, published_at: 1.day.ago, privacy: 'public', title_en: 'Join the co-op') }

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    sub_plan.update!(listed: true, name: 'Supporting member', participant_summary: 'Support the work and vote at the AGM.')
    create(:better_together_billing_plan, :one_time, listed: true, name: 'Friend', participant_summary: 'Free, with no payment.', **free_attrs)
  end

  after { Current.platform = nil }

  it 'captures a plan catalog block on a page' do
    block = create(:content_plan_catalog_block, heading_en: 'Ways to join')
    content_page.page_blocks.create!(block:, position: 0)

    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_plan_catalog_block',
      device: :both,
      metadata: { locale: I18n.default_locale, role: 'visitor', feature_set: 'billing_plan_blocks', flow: 'billing_plan_catalog_block',
                  source_spec: self.class.metadata[:file_path] },
      callouts: [{ id: 'plans', selector: "##{dom_id.call(block, :plans)}", title: 'Plans on a page',
                   bullets: ['The same cards as the catalog, for the plans this visitor may buy.'] }],
      narrative: {
        title: 'Plan catalog block',
        audience: %w[content_editor end_user],
        journey_step: 'As an editor I add the plan catalog block to a page; visitors see the plans they can buy.',
        callouts: [{ id: 'plans', title: 'Plan cards', description: 'Price, summary and a button into checkout.' }],
        accessibility_notes: 'The block is a labelled section; each plan is an article with its own heading.'
      }
    ) do
      visit "/#{I18n.default_locale}/#{content_page.slug}"
      expect(page).to have_css("##{dom_id.call(block, :plans)}")
      page.execute_script("document.querySelector('##{dom_id.call(block, :plans)}').scrollIntoView({block: 'center'})")
    end
  end

  it 'captures a plan button block on a page' do
    block = create(:content_plan_button_block, plan_id: sub_plan.id, display_as: 'card')
    content_page.page_blocks.create!(block:, position: 0)
    buy = "##{dom_id.call(sub_plan, "block_#{block.id}_buy")}"

    BetterTogether::CapybaraScreenshotEngine.capture(
      'billing_plan_button_block',
      device: :both,
      metadata: { locale: I18n.default_locale, role: 'visitor', feature_set: 'billing_plan_blocks', flow: 'billing_plan_button_block',
                  source_spec: self.class.metadata[:file_path] },
      callouts: [{ id: 'buy', selector: buy, title: 'Start checkout', bullets: ['One plan, offered from any page.'] }],
      narrative: {
        title: 'Plan button block',
        audience: %w[content_editor end_user],
        journey_step: 'As an editor I offer one plan from a page; visitors it is offered to see the card and button.',
        callouts: [{ id: 'buy', title: 'Subscribe', description: 'Leads to checkout for this plan.' }],
        accessibility_notes: 'The button is a link with a plain text name.'
      }
    ) do
      visit "/#{I18n.default_locale}/#{content_page.slug}"
      expect(page).to have_css(buy)
      page.execute_script("document.querySelector('#{buy}').scrollIntoView({block: 'center'})")
    end
  end
end
