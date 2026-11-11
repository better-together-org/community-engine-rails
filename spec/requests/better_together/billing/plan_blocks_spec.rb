# frozen_string_literal: true

require 'rails_helper'

# The plan catalog block and the plan button block on a published page: they show what the policy lets this visitor see and buy.
RSpec.describe 'Plan blocks on a page', :no_auth do # rubocop:disable RSpec/DescribeClass
  include_context 'with subscription fixtures'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let(:page) { create(:better_together_page, published_at: 1.day.ago, privacy: 'public') }
  let(:add_block) { ->(block) { page.page_blocks.create!(block:, position: page.page_blocks.count) } }
  let(:show_page) do
    lambda {
      get better_together.render_page_path(path: page.slug, locale:)
      response.body
    }
  end
  let(:dom_id) { ->(*args) { ActionView::RecordIdentifier.dom_id(*args) } }

  describe 'the plan catalog block' do
    let(:block) { create(:content_plan_catalog_block, heading_en: 'Join us') }

    before { add_block.call(block) }

    it 'shows each listed plan as a card with its price and buy button' do
      sub_plan.update!(listed: true)
      prefix = "block_#{block.id}"

      body = show_page.call

      expect(body).to include('Join us', dom_id.call(block, :plans), dom_id.call(sub_plan, prefix), dom_id.call(sub_plan, "#{prefix}_buy"))
      expect(body).to include("/billing/checkout/new?locale=#{locale}&amp;plan_id=#{sub_plan.id}").or include("plan_id=#{sub_plan.id}")
    end

    it 'leaves out plans that are not listed' do
      sub_plan.update!(listed: false)

      expect(show_page.call).to include(dom_id.call(block, :empty))
    end

    it 'leaves out a plan limited to members when the visitor is not one' do
      sub_plan.update!(listed: true, restricted_to_members: true)

      body = show_page.call

      expect(body).not_to include(dom_id.call(sub_plan, "block_#{block.id}"))
      expect(body).to include(dom_id.call(block, :empty))
    end

    it 'shows the empty note when billing is off' do
      sub_plan.update!(listed: true)
      allow(BetterTogether::Billing).to receive(:enabled?).and_return(false)

      expect(show_page.call).to include(dom_id.call(block, :empty))
    end

    it 'shows no more plans than the limit' do
      sub_plan.update!(listed: true)
      create(:better_together_billing_plan, :one_time, listed: true, platform: host_platform, processor: nil, processor_price_id: nil,
                                                       processor_product_id: nil, amount_cents: 0, accepted_payment_methods: [])
      block.update!(item_limit: 1)

      expect(show_page.call.scan('billing-catalog-plan').size).to be <= 2
      expect(show_page.call.scan(%(class="card h-100 billing-catalog-plan")).size).to eq(1)
    end
  end

  describe 'the plan button block' do
    let(:block) { create(:content_plan_button_block, plan_id: sub_plan.id, display_as: 'card') }

    before { add_block.call(block) }

    it 'offers a plan that is not listed in the catalog, as a card' do
      sub_plan.update!(listed: false)

      expect(show_page.call).to include(dom_id.call(sub_plan, "block_#{block.id}"), dom_id.call(sub_plan, "block_#{block.id}_buy"))
    end

    it 'can be just the button' do
      block.update!(display_as: 'button')

      body = show_page.call

      expect(body).to include(dom_id.call(sub_plan, "block_#{block.id}_buy"))
      expect(body).not_to include(%(class="card h-100 billing-catalog-plan"))
    end

    it 'shows nothing to a visitor the plan is not offered to' do
      sub_plan.update!(restricted_to_subscribers: true)

      expect(show_page.call).not_to include(dom_id.call(sub_plan, "block_#{block.id}_buy"))
    end

    it 'shows nothing for an inactive plan' do
      sub_plan.update!(active: false)

      expect(show_page.call).not_to include(dom_id.call(sub_plan, "block_#{block.id}_buy"))
    end
  end
end
