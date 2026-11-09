# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Notifications::Catalog do
  it 'lists who hears about each kind' do
    expect(described_class.audiences('order_placed')).to eq(%i[buyer seller])
    expect(described_class.audiences(:payment_failed)).to eq(%i[buyer])
    expect(described_class.audiences('settings_changed')).to eq(%i[operator])
  end

  it 'marks the kinds that must always get through' do
    critical = described_class::KINDS.keys.select { |kind| described_class.critical?(kind) }

    expect(critical).to contain_exactly('payment_failed', 'payment_action_required', 'dispute_opened', 'settings_changed',
                                        'event_dead_lettered', 'plan_sync_failed')
    expect(described_class.critical?('order_paid')).to be(false)
  end

  it 'knows which kinds exist, and takes none that are not there' do
    expect(described_class.kind?('refund_issued')).to be(true)
    expect(described_class.kind?('stripe_invoice_paid')).to be(false)
    expect(described_class.critical?('nonsense')).to be(false)
  end

  it 'covers what Pay\'s own mailers sent, as notifications of ours' do
    pay_messages = %w[payment_succeeded refund_issued subscription_renewing payment_action_required payment_failed trial_ending trial_ended]

    expect(described_class::KINDS.keys).to include(*pay_messages)
  end

  it 'has copy in every locale for every kind and audience' do
    I18n.available_locales.each do |locale|
      I18n.with_locale(locale) do
        described_class::KINDS.each do |kind, config|
          config[:audiences].each do |audience|
            %w[title body].each do |part|
              text = I18n.t("better_together.billing.notifications.#{kind}.#{audience}.#{part}",
                            default: [:"better_together.billing.notifications.#{kind}.#{part}"], number: 'N', amount: 'A', method: 'M')
              expect(text).to be_a(String), "missing #{locale} #{kind}.#{audience}.#{part}"
              expect(text).not_to include('translation missing')
            end
          end
        end
      end
    end
  end
end
