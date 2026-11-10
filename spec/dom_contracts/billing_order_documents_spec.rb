# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the invoice and receipt downloads on the order page
# (spec/docs_screenshots/better_together/billing_order_documents_spec.rb targets these identifiers).
RSpec.describe 'Billing order documents DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with orders fixtures'
  include_context 'with billing switched on'

  let(:buyer) { BetterTogether::User.find_by!(email: 'manager@example.test').person }
  let!(:order) { place_order }
  let(:dom_id) { ActionView::RecordIdentifier }

  it 'exposes a container and a button for each document, by kind' do
    invoice = BetterTogether::Billing::Orders::GenerateDocument.call(order)

    get "/#{I18n.default_locale}/billing/orders/#{order.id}"

    expect(response.body).to include(%(id="#{dom_id.dom_id(order, :documents)}"), %(id="#{dom_id.dom_id(invoice, :download)}"),
                                     'billing-order-document-download', 'billing-order-invoice-download')
  end

  it 'offers the language to make the documents again in', :aggregate_failures do
    BetterTogether::Billing::Orders::GenerateDocument.call(order)

    get "/fr/billing/orders/#{order.id}"

    expect(response.body).to include(%(id="#{dom_id.dom_id(order, :regenerate_documents)}"), %(id="#{dom_id.dom_id(order, :document_locale)}"),
                                     %(id="#{dom_id.dom_id(order, :regenerate_documents_submit)}"))
  end

  it 'hides the language form when the page is in the language the documents were made in' do
    BetterTogether::Billing::Orders::GenerateDocument.call(order)

    get "/#{I18n.default_locale}/billing/orders/#{order.id}"

    expect(response.body).not_to include(dom_id.dom_id(order, :regenerate_documents))
  end

  it 'shows no container while there is nothing to download' do
    get "/#{I18n.default_locale}/billing/orders/#{order.id}"

    expect(response.body).not_to include(dom_id.dom_id(order, :documents))
  end
end
