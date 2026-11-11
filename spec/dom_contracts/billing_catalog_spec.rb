# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the public plan catalog: the stable identifiers that documentation screenshots and tooling target.
RSpec.describe 'Billing catalog DOM contract', type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with subscription fixtures'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }

  def expect_ids(*ids)
    ids.each { |id| expect(response.body).to include(%(id="#{id}")), "expected id=#{id.inspect} in the page" }
  end

  def dom_id(*) = ActionView::RecordIdentifier.dom_id(*)

  before { sub_plan.update!(listed: true) }

  it 'exposes the list, and a card, link, price and buy button per plan' do
    get "/#{locale}/billing/catalog"

    expect_ids('billing-catalog-page', 'billing-catalog-plans', dom_id(sub_plan, :catalog), dom_id(sub_plan, :catalog_link),
               dom_id(sub_plan, :catalog_price), dom_id(sub_plan, :buy))
  end

  it 'exposes the empty note' do
    sub_plan.update!(listed: false)

    get "/#{locale}/billing/catalog"

    expect_ids('billing-catalog-empty')
  end

  it 'exposes the plan page, its price, its buy button and the way back' do
    get "/#{locale}/billing/catalog/#{sub_plan.id}"

    expect_ids('billing-catalog-plan-page', 'billing-catalog-back', dom_id(sub_plan, :catalog_price), dom_id(sub_plan, :buy))
  end
end
