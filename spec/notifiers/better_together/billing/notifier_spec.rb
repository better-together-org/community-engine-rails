# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Notifier do
  include_context 'with billing notifications'

  let(:order) { place_order }

  # Placing the order told people about it; start each example with an empty inbox.
  before do
    order
    clear_enqueued_jobs
    Noticed::Notification.delete_all
    Noticed::Event.delete_all
    BetterTogether::Billing::NotificationReceipt.delete_all
    ActionMailer::Base.deliveries.clear
  end

  def notify(kind, recipient = buyer, audience: :buyer, subject: order)
    deliver_now { described_class.with(record: subject, kind:, audience:).deliver_later([recipient]) }
    inbox(recipient).order(:created_at).last
  end

  describe 'what it says' do
    it 'says it in the reader\'s language, with the order\'s details' do
      notification = notify('order_paid')
      event = notification.event

      expect(event.title).to eq("Order #{order.number} is paid")
      expect(event.body).to include('$45.00')
    end

    it 'says it differently to the seller' do
      notification = notify('order_placed', steward, audience: :seller)

      expect(notification.event.title).to eq("New order #{order.number}")
    end

    it 'uses the reader\'s own locale in the message it sends to the app' do
      buyer.update!(locale: 'fr')

      notification = notify('order_paid')
      message = notification.event.build_message(notification)

      expect(message[:title]).to include('payée')
    end

    it 'links the buyer to their order and a steward to the sale' do
      expect(notify('order_paid').event.url).to eq(BetterTogether::Engine.routes.url_helpers.billing_order_path(order, locale: I18n.locale))
      expect(notify('order_paid', steward,
                    audience: :seller).event.url).to eq(BetterTogether::Engine.routes.url_helpers.billing_sale_path(order, locale: I18n.locale))
    end

    it 'links a change to a payment method to the payment methods screen' do
      BetterTogether::Billing.register_builtin_processors!
      setting = host_platform.billing_processor_settings.create!(processor: 'cash')

      expect(notify('settings_changed', steward, audience: :operator, subject: setting).event.url)
        .to eq(BetterTogether::Engine.routes.url_helpers.billing_processor_settings_path(locale: I18n.locale))
    end

    it 'never carries payment instructions or payee details' do
      BetterTogether::Billing.register_builtin_processors!
      setting = host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true,
                                                                 settings: { 'instructions' => 'Pay Alex at 4711 Harbour Road' })

      event = notify('settings_changed', steward, audience: :operator, subject: setting).event

      expect([event.title, event.body, event.url].join(' ')).not_to include('4711', 'Harbour', 'Alex')
    end
  end

  describe 'which platform it is for' do
    it 'is the record\'s, not the request\'s or the host\'s' do
      other = create(:better_together_platform)
      Current.platform = host_platform
      foreign_order = create(:better_together_billing_order, platform: other, buyer:)

      notification = notify('order_paid', buyer, subject: foreign_order)

      expect(notification.platform_id).to eq(other.id)
    ensure
      Current.platform = nil
    end
  end

  describe 'whether it is emailed' do
    it 'emails someone who has emails on' do
      expect { notify('order_paid') }.to change(ActionMailer::Base.deliveries, :count).by(1)
    end

    it 'does not email someone who turned emails off, for an ordinary notice' do
      buyer.update!(notify_by_email: false)

      expect { notify('order_paid') }.not_to(change(ActionMailer::Base.deliveries, :count))
      expect(inbox(buyer).count).to eq(1)
    end

    it 'emails a critical notice even to someone who turned emails off' do
      buyer.update!(notify_by_email: false)

      expect { notify('payment_failed') }.to change(ActionMailer::Base.deliveries, :count).by(1)
    end

    it 'sends the app message either way' do
      buyer.update!(notify_by_email: false)

      expect { notify('order_paid') }.to change { inbox(buyer).count }.by(1)
    end
  end

  it 'is critical only for the kinds the catalog says' do
    expect(described_class.new(params: { kind: 'payment_failed', audience: :buyer })).to be_critical
    expect(described_class.new(params: { kind: 'order_paid', audience: :buyer })).not_to be_critical
  end

  it 'delivers on the billing queue, so a payment message never waits behind other jobs' do
    queues = described_class.delivery_methods.values.map { |method| method.config[:queue] }

    expect(queues).to all(eq(:billing))
  end

  it 'needs its kind and audience' do
    expect { described_class.with(record: order).deliver_later([buyer]) }.to raise_error(Noticed::ValidationError)
  end
end
