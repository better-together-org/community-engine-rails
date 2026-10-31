# frozen_string_literal: true

# Cash, a cheque and an e-transfer switched on for the host platform, a buyer, a steward and a CAD plan
# for the e-transfer, and the helpers to place an order paid each way.
RSpec.shared_context 'with offline payment fixtures' do
  include_context 'with billing notifications'
  include_context 'with builtin billing processors'

  let(:cad_plan) { create(:better_together_billing_plan, amount_cents: 6000, currency: 'CAD') }
  let(:other_buyer_user) { find_or_create_test_user("other-buyer-#{SecureRandom.hex(4)}@example.test", password) }
  let(:other_buyer) { other_buyer_user.person }

  let(:offline_details) do
    { 'cash' => { 'instructions' => 'Hand it to Alex at the hall' },
      'cheque' => { 'payee_name' => 'Alex Seller', 'address' => '4711 Harbour Road' },
      'etransfer' => { 'recipient_email' => 'alex@example.test' } }
  end

  before do
    steward
    other_steward
    plan
  end

  def enable_offline(method, **attrs)
    host_platform.billing_processor_settings.find_or_create_by!(processor: method) do |setting|
      setting.assign_attributes({ enabled: true, acknowledge: true, settings: offline_details.fetch(method) }.merge(attrs))
    end
  end

  # An order the buyer will pay by `method`. Placed with the method's setting on and the agreements accepted.
  def place_offline(method = 'cash', purchasable: nil, **attrs)
    enable_offline(method)
    purchasable ||= method == 'etransfer' ? cad_plan : plan
    place_order(payment_method: method, lines: [{ purchasable: }], **attrs)
  end

  def offline_for(order) = order.offline_payments.first

  def transition = BetterTogether::Billing::OfflinePayments::Transition

  # The buyer's and steward's billing notices, oldest first, as their kinds.
  def clear_notices
    clear_enqueued_jobs
    Noticed::Notification.delete_all
    Noticed::Event.delete_all
    BetterTogether::Billing::NotificationReceipt.delete_all
    ActionMailer::Base.deliveries.clear
  end
end
