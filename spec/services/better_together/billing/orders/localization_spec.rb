# frozen_string_literal: true

require 'rails_helper'

# What an order keeps of the plan and tax names, in every language, and which language its documents are written in.
RSpec.describe 'Order localization' do # rubocop:disable RSpec/DescribeClass
  include_context 'with orders fixtures'
  include_context 'with quebec tax'

  let(:order) { place_order(tax_address: quebec_address) }

  def text_of(document)
    cells = document.sections.values.flatten(2).map { |cell| (cell.is_a?(Hash) ? cell[:content] : cell).to_s }
    cells.join(' ')
  end

  before do
    plan.update!(name_fr: 'Adhésion hébergée', name_uk: 'Хостингове членство')
    BetterTogether::Billing::TaxRate.find_each { |rate| rate.update!(label_fr: { 'GST' => 'TPS', 'QST' => 'TVQ' }.fetch(rate.label)) }
  end

  describe 'the snapshot' do
    it 'keeps the plan name and each tax label in every language it had when the order was placed', :aggregate_failures do
      line = order.line_items.first
      expect(line.description(locale: :en)).to eq(plan.name(locale: :en))
      expect(line.description(locale: :fr)).to eq('Adhésion hébergée')
      expect(line.description(locale: :uk)).to eq('Хостингове членство')
      expect(order.tax_lines.map { |tax| tax.label(locale: :fr) }).to contain_exactly('TPS', 'TVQ')
    end

    it 'does not change when the plan is renamed or a rate is relabelled later', :aggregate_failures do
      order
      plan.update!(name_fr: 'Autre nom')
      BetterTogether::Billing::TaxRate.find_each { |rate| rate.update!(label_fr: 'X') }

      expect(order.reload.line_items.first.description(locale: :fr)).to eq('Adhésion hébergée')
      expect(order.tax_lines.map { |tax| tax.label(locale: :fr) }).to contain_exactly('TPS', 'TVQ')
    end

    it 'keeps the agreement titles in every language', :aggregate_failures do
      acceptance = order.agreement_acceptances.first
      agreement = acceptance.agreement

      expect(acceptance.agreement_title(locale: :fr)).to eq(agreement.title(locale: :fr))
      expect(acceptance.agreement_title(locale: :en)).to eq(agreement.title(locale: :en))
    end
  end

  describe 'the language of the documents' do
    it 'is the language the order was placed in when the buyer has none', :aggregate_failures do
      I18n.with_locale(:es) { order }
      allow(order.buyer).to receive(:locale).and_return(nil)

      expect(order.placed_locale).to eq('es')
      expect(order.locale_for_documents).to eq(:es)
    end

    it 'is the buyer\'s language when they have one', :aggregate_failures do
      I18n.with_locale(:es) { order }
      allow(order.buyer).to receive(:locale).and_return('fr')

      expect(order.locale_for_documents).to eq(:fr)
    end

    it 'prefers the language chosen for the documents over everything else' do
      order.update!(document_locale: 'fr')

      expect(order.locale_for_documents).to eq(:fr)
    end

    it 'falls back to the platform language when nothing else is known' do
      order.update_columns(placed_locale: nil, document_locale: nil) # rubocop:disable Rails/SkipsModelValidations
      allow(order.buyer).to receive(:locale).and_return(nil)

      expect(order.locale_for_documents).to eq(I18n.default_locale)
    end

    it 'refuses a language the app does not support' do
      order.document_locale = 'xx'

      expect(order).not_to be_valid
    end

    it 'writes the PDF text in the chosen language, whatever the language of the request', :aggregate_failures do
      french = I18n.with_locale(:en) { BetterTogether::Billing::Orders::Document.new(order, locale: :fr) }
      ukrainian = I18n.with_locale(:en) { BetterTogether::Billing::Orders::Document.new(order, locale: :uk) }

      expect(text_of(french)).to include('Adhésion hébergée', 'TPS', 'TVQ')
      expect(text_of(ukrainian)).to include('Хостингове членство')
      expect(french.to_pdf).to start_with('%PDF')
    end
  end

  describe 'making the documents again in another language' do
    it 'stores a new document in that language and supersedes the one before', :aggregate_failures do
      first = BetterTogether::Billing::Orders::GenerateDocument.call(order)
      second = BetterTogether::Billing::Orders::GenerateDocument.call(order, locale: :fr)

      expect(second).not_to eq(first)
      expect(first.reload).not_to be_current
      expect(order.invoice_document).to eq(second)
    end
  end
end
