# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Orders::GenerateDocument do
  include_context 'with orders fixtures'
  include_context 'with quebec tax'

  let(:order) { place_order(tax_address: quebec_address) }

  def pay!
    create(:better_together_billing_payment, order:, amount_cents: order.total_cents, status: 'succeeded', currency: 'USD',
                                             paid_at: Time.current)
    BetterTogether::Billing::Orders::Settle.call(order)
    order.reload
  end

  it 'stores the PDF as a private upload made by the buyer, joined to the order', :aggregate_failures do
    document = described_class.call(order)

    expect(document).to be_persisted
    expect(document.kind).to eq('invoice')
    expect(document.upload.creator).to eq(order.buyer)
    expect(document.upload).to be_privacy_private
    expect(document.upload.download).to start_with('%PDF')
    expect(document.filename.to_s).to eq("invoice-#{order.number}.pdf")
    expect(order.invoice_document).to eq(document)
  end

  it 'returns the stored document, instead of making another, while nothing has changed', :aggregate_failures do
    first = described_class.call(order)

    expect(described_class.call(order)).to eq(first)
    expect(order.documents.count).to eq(1)
  end

  it 'returns the document a concurrent call stored first instead of failing on the unique index', :aggregate_failures do
    service = described_class.new(order)
    stored = described_class.call(order)
    allow(service).to receive(:existing_document).and_return(nil, stored)
    allow(order.documents).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)

    expect(service.call).to eq(stored)
  end

  it 'makes a receipt when the order is paid and keeps the invoice as it was', :aggregate_failures do
    invoice = described_class.call(order)
    pay!
    receipt = described_class.call(order)

    expect(receipt.kind).to eq('receipt')
    expect(order.receipt_document).to eq(receipt)
    expect(order.invoice_document).to eq(invoice)
  end

  it 'supersedes the document of a kind when its figures change, and keeps the old one', :aggregate_failures do
    pay!
    first = described_class.call(order)
    payment = order.payments.first
    BetterTogether::Billing::Refund.create!(payment:, platform: order.platform, amount_cents: 100, tax_cents: 0, currency: 'USD',
                                            status: 'recorded', idempotency_key: SecureRandom.uuid)
    second = described_class.call(order.reload)

    expect(second).not_to eq(first)
    expect(first.reload).not_to be_current
    expect(order.receipt_document).to eq(second)
  end

  describe 'the time zone it is written in' do
    it 'is the buyer\'s own when they set one', :aggregate_failures do
      order.buyer.update!(preferences: order.buyer.preferences.merge('time_zone' => 'Asia/Tokyo'))

      document = described_class.call(order)

      expect(document.time_zone).to eq('Asia/Tokyo')
    end

    it 'falls back to the platform\'s when the buyer has not set one' do
      order.buyer.update!(preferences: order.buyer.preferences.except('time_zone'))
      order.platform.update!(time_zone: 'Europe/Paris')

      expect(described_class.call(order).time_zone).to eq('Europe/Paris')
    end
  end

  describe 'the structured data in the PDF', :aggregate_failures do
    it 'has the Factur-X XML with a breakdown per tax and the JSON-LD', :aggregate_failures do
      pdf = described_class.call(order).upload.download
      xml = BetterTogether::Billing::Orders::Document.new(order).xml
      doc = Nokogiri::XML(xml)
      ns = { 'ram' => 'urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100' }

      expect(pdf).to include('/AFRelationship /Data'.b, '/EmbeddedFiles'.b, 'CrossIndustryInvoice'.b, 'schema.org'.b)
      expect(doc.xpath('//ram:ApplicableTradeTax/ram:CalculatedAmount', ns).map(&:text)).to contain_exactly('2.25', '4.49')
      expect(doc.at_xpath('//ram:GrandTotalAmount', ns).text).to eq('51.74')
      expect(doc.at_xpath('//ram:GuidelineSpecifiedDocumentContextParameter/ram:ID', ns).text).to eq('urn:factur-x.eu:1p0:basicwl')
    end

    it 'has JSON-LD that says which lines are taxed', :aggregate_failures do
      json = JSON.parse(BetterTogether::Billing::Orders::Document.new(order).json)

      expect(json['@type']).to eq('Invoice')
      expect(json.dig('referencesOrder', 'orderedItem', 0, 'orderedItem', 'additionalProperty', 'value')).to be(true)
    end

    it 'puts a line amount on the ordered Product offer, never as a price on the OrderItem', :aggregate_failures do
      json = JSON.parse(BetterTogether::Billing::Orders::Document.new(order).json)
      item = json.dig('referencesOrder', 'orderedItem', 0)
      spec = item.dig('orderedItem', 'offers', 'priceSpecification')

      expect(item).not_to have_key('price')
      expect(spec).to include('@type' => 'PriceSpecification', 'priceCurrency' => order.currency)
      expect(spec['price']).to match(/\A\d+\.\d{2}\z/)
      expect(spec.dig('eligibleQuantity', 'value')).to eq(item['orderQuantity'])
    end
  end
end
