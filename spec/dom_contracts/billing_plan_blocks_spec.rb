# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the plan blocks on a page: the identifiers screenshots and tooling target.
RSpec.describe 'Billing plan blocks DOM contract', :no_auth, type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with subscription fixtures'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let(:page) { create(:better_together_page, published_at: 1.day.ago, privacy: 'public') }
  let(:dom_id) { ->(*args) { ActionView::RecordIdentifier.dom_id(*args) } }
  let(:show_page) do
    lambda {
      get better_together.render_page_path(path: page.slug, locale:)
      response.body
    }
  end

  before { sub_plan.update!(listed: true) }

  it 'exposes the catalog block, its grid, and a card, link, price and buy button per plan' do
    block = create(:content_plan_catalog_block)
    page.page_blocks.create!(block:, position: 0)
    prefix = "block_#{block.id}"

    expect(show_page.call).to include(%(id="#{dom_id.call(block)}"), %(id="#{dom_id.call(block, :plans)}"),
                                      %(id="#{dom_id.call(sub_plan, prefix)}"), %(id="#{dom_id.call(sub_plan, "#{prefix}_link")}"),
                                      %(id="#{dom_id.call(sub_plan, "#{prefix}_price")}"), %(id="#{dom_id.call(sub_plan, "#{prefix}_buy")}"))
  end

  it 'exposes the catalog block empty note' do
    sub_plan.update!(listed: false)
    block = create(:content_plan_catalog_block)
    page.page_blocks.create!(block:, position: 0)

    expect(show_page.call).to include(%(id="#{dom_id.call(block, :empty)}"))
  end

  it 'exposes the button block and its buy button' do
    block = create(:content_plan_button_block, plan_id: sub_plan.id, display_as: 'button')
    page.page_blocks.create!(block:, position: 0)

    expect(show_page.call).to include(%(id="#{dom_id.call(block)}"), %(id="#{dom_id.call(sub_plan, "block_#{block.id}_buy")}"))
  end
end
