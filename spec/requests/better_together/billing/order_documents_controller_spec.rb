# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::OrderDocumentsController do
  include_context 'with orders fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:password) { 'SecureTest123!@#' }
  let(:steward) { find_or_create_test_user("docs-steward-#{SecureRandom.hex(4)}@example.test", password, :platform_manager) }
  let(:member) { find_or_create_test_user("docs-member-#{SecureRandom.hex(4)}@example.test", password) }
  let(:stranger) { find_or_create_test_user("docs-stranger-#{SecureRandom.hex(4)}@example.test", password) }
  let(:buyer) { member.person }
  let!(:order) { place_order }

  def sale_documents_path = better_together.billing_sale_documents_path(order, locale:)
  def order_documents_path = better_together.billing_order_documents_path(order, locale:)

  before { BetterTogether::Billing::Orders::GenerateDocument.call(order) }

  context 'when signed in as a steward' do
    before { sign_in steward }

    it 'makes the documents again in the chosen language and keeps it for the ones made later', :aggregate_failures do
      expect do
        post sale_documents_path, params: { document_locale: 'fr' }
      end.to change { order.documents.count }.by(1)

      expect(response).to redirect_to(better_together.billing_sale_path(order, locale:))
      expect(order.reload.document_locale).to eq('fr')
      expect(order.invoice_document).to be_current
      expect(order.locale_for_documents).to eq(:fr)
    end

    it 'refuses a language the app does not support and changes nothing', :aggregate_failures do
      expect { post sale_documents_path, params: { document_locale: 'xx' } }.not_to(change { order.documents.count })

      expect(response).to have_http_status(:found)
      expect(order.reload.document_locale).to be_nil
    end

    it 'refuses to make them again in the language they are already in', :aggregate_failures do
      expect { post sale_documents_path, params: { document_locale: 'en' } }.not_to(change { order.documents.count })
      expect(flash[:alert]).to eq(I18n.t('better_together.billing.order_documents.already_in_language'))
    end

    it 'keeps the language the documents were made in when the buyer changes their own language', :aggregate_failures do
      order.buyer.update!(locale: 'fr')
      expect(order.reload.locale_for_documents).to eq(:fr)
      expect(order.documents_locale).to eq('en')

      get better_together.billing_sale_path(order, locale: :fr)
      expect(response.body).to include(ActionView::RecordIdentifier.dom_id(order, :regenerate_documents))

      expect { post sale_documents_path, params: { document_locale: 'fr' } }.to change { order.documents.current.pluck(:locale).uniq }
        .from(['en']).to(['fr'])
    end

    it 'shows the language form on the sale when read in another language' do
      get better_together.billing_sale_path(order, locale: :fr)

      expect(response.body).to include(ActionView::RecordIdentifier.dom_id(order, :regenerate_documents),
                                       ActionView::RecordIdentifier.dom_id(order, :document_locale))
    end
  end

  context 'when signed in as the buyer' do
    before { sign_in member }

    it 'makes their own documents again in another language', :aggregate_failures do
      post order_documents_path, params: { document_locale: 'es' }

      expect(response).to redirect_to(better_together.billing_order_path(order, locale:))
      expect(order.reload.document_locale).to eq('es')
    end

    it 'is turned away from the steward route' do
      post sale_documents_path, params: { document_locale: 'es' }

      expect(response).not_to have_http_status(:ok)
      expect(order.reload.document_locale).to be_nil
    end
  end

  it 'does not let someone else change another buyer\'s documents', :aggregate_failures do
    sign_in stranger

    post order_documents_path, params: { document_locale: 'es' }

    expect(response).to have_http_status(:not_found)
    expect(order.reload.document_locale).to be_nil
  end
end
