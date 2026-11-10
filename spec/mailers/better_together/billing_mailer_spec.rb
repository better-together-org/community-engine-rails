# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::BillingMailer do
  include_context 'with billing notifications'

  let(:order) { place_order }
  let(:notifier) { BetterTogether::Billing::Notifier.new(record: order, params: { kind: 'order_paid', audience: :buyer }) }
  let(:mail) { described_class.with(recipient: buyer, notifier:).notification }

  it 'goes to the recipient, with the notification\'s title as the subject' do
    expect(mail.to).to eq([buyer.email])
    expect(mail.subject).to eq("Order #{order.number} is paid")
  end

  it 'says what happened and links into the app' do
    expect_mail_html_content(mail, order.number)
    expect_mail_html_content(mail, buyer.name)
    expect(mail.html_part.body.decoded).to include(BetterTogether::Engine.routes.url_helpers.billing_order_path(order, locale: I18n.locale))
    expect(mail.text_part.body.decoded).to include("/billing/orders/#{order.id}")
  end

  it 'has a text part as well as a html part' do
    expect(mail.text_part.body.decoded).to include(order.number)
  end

  it 'says it never includes payment details, and who to ask' do
    expect_mail_html_content(mail, I18n.t('better_together.billing_mailer.notification.safety'))
    expect(mail.html_part.body.decoded).to include(Pay.support_email.to_s)
  end

  it 'reads in the recipient\'s language' do
    buyer.update!(locale: 'fr')

    expect(mail.subject).to include('payée')
  end

  it 'never contains payment instructions, however the notification is built' do
    BetterTogether::Billing.register_builtin_processors!
    setting = host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true,
                                                               settings: { 'instructions' => 'Pay Alex at 4711 Harbour Road' })
    settings_notifier = BetterTogether::Billing::Notifier.new(record: setting, params: { kind: 'settings_changed', audience: :operator })
    steward_mail = described_class.with(recipient: steward, notifier: settings_notifier).notification

    expect(steward_mail.html_part.body.decoded + steward_mail.text_part.body.decoded).not_to include('4711', 'Harbour')
  end

  describe 'the order summary' do
    include_context 'with quebec tax'

    let(:order) { place_order(tax_address: quebec_address) }

    it 'is the full summary in both parts: a row per tax, the total and the registration numbers', :aggregate_failures do
      expect_mail_html_contents(mail, 'GST', 'QST', '9.975%', '$51.74', '123456789RT0001', '1234567890TQ0001')
      expect(mail.html_part.body.decoded).to include('billing-summary-email-total', 'billing-summary-email-tax-1')
      expect(mail.text_part.body.decoded).to include('GST', 'QST', '9.975%', '$51.74', '123456789RT0001', '1234567890TQ0001')
    end

    it 'shows a total and no tax rows for an order without tax', :aggregate_failures do
      untaxed_notifier = BetterTogether::Billing::Notifier.new(record: place_order(tax_address: { country_iso: 'DE' }),
                                                               params: {
                                                                 kind: 'order_paid', audience: :buyer
                                                               })
      untaxed = described_class.with(recipient: buyer, notifier: untaxed_notifier).notification

      expect(untaxed.html_part.body.decoded).to include('billing-summary-email-total')
      expect(untaxed.html_part.body.decoded).not_to include('billing-summary-email-tax-0', 'billing-summary-email-registrations')
    end
  end
end
