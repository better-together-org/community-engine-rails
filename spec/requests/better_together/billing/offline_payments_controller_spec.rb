# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::OfflinePaymentsController do
  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:order) { place_offline('cash') }
  let(:offline) { offline_for(order) }
  let(:other_platform) { create(:better_together_platform) }

  def queue_path = better_together.billing_offline_payments_path(locale:)
  def act_path(action, record = offline, **) = better_together.public_send(:"#{action}_billing_offline_payment_path", record, locale:, **)

  it 'sends a visitor to sign in' do
    get queue_path

    expect(response).to have_http_status(:found)
  end

  it 'turns a signed-in non-steward away' do
    offline
    sign_in buyer_user

    get queue_path

    expect(response.body).not_to include('billing-offline-queue')
    expect(response).not_to have_http_status(:ok)
  end

  it 'does not let a buyer confirm their own payment' do
    sign_in buyer_user

    patch act_path(:receive)

    expect(offline.reload.status).to eq('awaiting')
  end

  it 'is a 404 while billing is off' do
    sign_in steward_user
    allow(BetterTogether::Billing::Configuration).to receive(:requested?).and_return(false)

    get queue_path

    expect(response).to have_http_status(:not_found)
  end

  context 'when signed in as a steward' do
    before { sign_in steward_user }

    it 'lists what is waiting, the claimed first and marked' do
      waiting = offline
      claimed = offline_for(place_offline('cash', buyer: other_buyer))
      transition.claim(claimed, reference: 'sent')

      get queue_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('billing-offline-queue', ActionView::RecordIdentifier.dom_id(waiting), ActionView::RecordIdentifier.dom_id(claimed),
                                       ActionView::RecordIdentifier.dom_id(claimed, :claimed_badge))
      expect(response.body.index(ActionView::RecordIdentifier.dom_id(claimed))).to be < response.body.index(ActionView::RecordIdentifier.dom_id(waiting))
    end

    it 'offers to confirm a payment the buyer never said anything about' do
      expect(offline.claimed_at).to be_nil

      get queue_path

      expect(response.body).to include("billing-offline-confirm-btn-#{order.id}")
    end

    it 'says so when nothing is waiting' do
      get queue_path

      expect(response.body).to include('billing-offline-queue-empty')
    end

    it 'does not list another platform\'s payments, or what a community sold' do
      foreign_order = create(:better_together_billing_order, :awaiting_payment, platform: other_platform, total_cents: 100)
      foreign_payment = create(:better_together_billing_payment, order: foreign_order, platform_id: other_platform.id, processor: 'cash',
                                                                 amount_cents: 100)
      foreign = foreign_order.offline_payments.create!(platform_id: other_platform.id, payment: foreign_payment, processor: 'cash')

      get queue_path
      expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(foreign))

      patch act_path(:receive, foreign)
      expect(response).to have_http_status(:not_found)
      expect(foreign.reload.status).to eq('awaiting')
    end

    it 'marks a payment received, with a reference and a date, and tells the buyer' do
      clear_notices
      deliver_now { patch act_path(:receive), params: { seller_reference: 'envelope 3', received_on: 3.days.ago.to_date.iso8601 } }

      expect(response).to redirect_to(queue_path)
      expect(flash[:notice]).to be_present
      expect(offline.reload).to have_attributes(status: 'confirmed', seller_reference: 'envelope 3', received_on: 3.days.ago.to_date,
                                                confirmed_by: steward)
      expect(order.reload).to be_paid
      expect(kinds_for(buyer)).to include('payment_confirmed')
    end

    it 'goes back to the sale it came from' do
      patch act_path(:receive, from: 'sale')

      expect(response).to redirect_to(better_together.billing_sale_path(order, locale:))
    end

    it 'ignores a date that is not a date' do
      patch act_path(:receive), params: { received_on: 'tomorrow-ish' }

      expect(offline.reload).to have_attributes(status: 'confirmed', received_on: nil)
    end

    it 'rejects a payment with a reason the buyer can see' do
      patch act_path(:reject), params: { reason: 'nothing arrived' }

      expect(offline.reload).to have_attributes(status: 'rejected', rejection_reason: 'nothing arrived')
      expect(order.reload).to be_cancelled
    end

    it 'says so, rather than failing, when a payment cannot be changed that way' do
      transition.reject(offline, by: steward)

      patch act_path(:receive)

      expect(response).to redirect_to(queue_path)
      expect(flash[:alert]).to eq(I18n.t('better_together.billing.offline_payments.refused.not_allowed'))
    end

    it 'clears and bounces a received cheque' do
      cheque = offline_for(place_offline('cheque'))
      transition.receive(cheque, by: steward)

      patch act_path(:clear, cheque)
      expect(cheque.reload.status).to eq('cleared')

      other = offline_for(place_offline('cheque', buyer: other_buyer))
      transition.receive(other, by: steward)
      patch act_path(:bounce, other)
      expect(other.reload.status).to eq('bounced')
    end

    it 'shows the confirm, reject and refund forms on the sale page' do
      transition.claim(offline, reference: 'ref')
      get better_together.billing_sale_path(order, locale:)

      expect(response.body).to include("billing-offline-receive-form-#{order.id}", "billing-offline-confirm-btn-#{order.id}",
                                       "billing-offline-reject-btn-#{order.id}", ActionView::RecordIdentifier.dom_id(offline, :claimed_at))
      expect_html_content('ref')
    end
  end

  describe 'a long queue' do
    let(:queue_query_count) do
      lambda do
        count = 0
        counter = lambda do |*, payload|
          count += 1 unless %w[SCHEMA TRANSACTION].include?(payload[:name]) || payload[:sql].match?(/\A(BEGIN|COMMIT|SAVEPOINT|RELEASE)/)
        end
        ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') { get queue_path }
        count
      end
    end

    it 'does not run more queries per extra payment' do
      offline
      sign_in steward_user
      queue_query_count.call # warm up
      before_count = queue_query_count.call
      4.times { place_offline('cash', buyer: create(:better_together_person)) }

      expect(queue_query_count.call).to be <= before_count + 1
    end

    it 'puts claimed payments first and shows one page at a time' do
      first = offline
      claimed = place_offline('cash', buyer: create(:better_together_person))
      offline_for(claimed).update!(claimed_at: Time.current)
      sign_in steward_user
      stub_const('BetterTogether::Billing::OfflinePaymentsController::PER_PAGE', 1)

      get queue_path

      rows = response.parsed_body.css('#billing-offline-queue tbody tr')
      expect(rows.size).to eq(1)
      expect(rows.first['id']).to eq("billing_offline_payment_#{offline_for(claimed).id}")
      expect(first).to be_present
      expect(response.body).to include('billing-offline-queue-pagination')
    end
  end
end
