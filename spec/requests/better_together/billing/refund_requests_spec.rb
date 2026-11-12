# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Billing refund requests', type: :request do # rubocop:disable RSpec/DescribeClass, RSpecRails/InferredSpecType
  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:order) { place_offline('cash') }
  let(:offline) { offline_for(order) }
  let(:payment) { offline.payment }
  let(:request_model) { BetterTogether::Billing::RefundRequest }

  def new_path(record = order) = better_together.new_billing_order_refund_request_path(record, locale:)
  def create_path(record = order) = better_together.billing_order_refund_requests_path(record, locale:)
  def queue_path = better_together.billing_refund_requests_path(locale:)
  def decide_path(req) = better_together.decide_billing_refund_request_path(req, locale:)

  def ask(**params) = post(create_path, params: { reason: 'requested_by_buyer' }.merge(params))

  before do
    transition.receive(offline, by: steward)
    payment.reload
  end

  context 'when signed in as the buyer' do
    before { sign_in buyer_user }

    context 'with a refund policy in force' do
      let(:policy) { BetterTogether::Agreement.find_by!(platform: host_platform, identifier: 'refund_policy') }

      before do
        purchase_agreements_for(host_platform)
        policy.update!(lifecycle_state: 'active')
      end

      after { policy.update!(lifecycle_state: 'draft') }

      it 'asks for the policy on the form' do
        get new_path

        expect(response.body).to include('billing-refund-policy-view', 'billing-refund-policy-accept')
      end

      it 'refuses a request until the policy is ticked' do
        expect { ask }.not_to change(request_model, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'sends the request and records the acceptance when it is ticked' do
        expect { ask(refund_policy_agreement: '1') }.to change(request_model, :count).by(1)
        expect(policy.accepted_by?(buyer)).to be(true)
      end

      it 'does not ask again once accepted' do
        ask(refund_policy_agreement: '1')
        request_model.destroy_all

        get new_path

        expect(response.body).to include('billing-refund-policy-accepted')
        expect { ask }.to change(request_model, :count).by(1)
      end
    end

    it 'shows the form with what can still be given back' do
      get new_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('billing-refund-request-form')
    end

    it 'records a request, and tells the buyer and the stewards' do
      clear_notices
      deliver_now { ask(amount: '10', details: 'Too small') }

      expect(response).to redirect_to(better_together.billing_order_path(order, locale:))
      expect(request_model.last).to have_attributes(order:, requester: buyer, amount_cents: 1000, status: 'pending', details: 'Too small')
      expect(kinds_for(steward)).to include('refund_requested')
    end

    it 'refuses a second request while one is waiting' do
      ask
      expect { ask }.not_to change(request_model, :count)
      expect(response).to have_http_status(:found)
    end

    it 'refuses more than can be given back' do
      expect { ask(amount: '9999') }.not_to change(request_model, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'lets the buyer withdraw a waiting request' do
      ask
      req = request_model.last

      post better_together.cancel_billing_order_refund_request_path(order, req, locale:)

      expect(req.reload.status).to eq('cancelled')
    end

    it 'does not show the steward queue' do
      get queue_path

      expect(response).to have_http_status(:found)
      expect(response.location).not_to include('refund_requests')
    end
  end

  context 'when signed in as another person' do
    it 'cannot ask on someone else\'s order' do
      sign_in create(:user, :confirmed)

      expect { ask }.not_to change(request_model, :count)
    end
  end

  context 'when signed in as a steward' do
    let(:req) do
      sign_in buyer_user
      ask(amount: '20')
      request_model.last
    end

    before { req }

    it 'lists the queue' do
      sign_in steward_user

      get queue_path

      expect(response.body).to include("refund_request_#{req.id}")
    end

    it 'approves, gives the money back as a recorded refund, and tells the buyer' do
      sign_in steward_user
      clear_notices

      deliver_now { post decide_path(req), params: { outcome: 'approve', decision_note: 'Sorry about that' } }

      expect(req.reload).to have_attributes(status: 'approved', approved_amount_cents: 2000, decision_note: 'Sorry about that',
                                            decided_by: steward)
      expect(payment.reload.refunds.sum(:amount_cents)).to eq(2000)
      expect(kinds_for(buyer)).to include('refund_request_decided')
    end

    it 'approves part' do
      sign_in steward_user

      post decide_path(req), params: { outcome: 'approve', approved_amount: '5' }

      expect(req.reload).to have_attributes(status: 'partially_approved', approved_amount_cents: 500)
      expect(payment.reload.refunds.sum(:amount_cents)).to eq(500)
    end

    it 'declines only with a reply, and gives nothing back' do
      sign_in steward_user

      post decide_path(req), params: { outcome: 'decline' }
      expect(req.reload.status).to eq('pending')

      post decide_path(req), params: { outcome: 'decline', decision_note: 'Past the window' }
      expect(req.reload).to have_attributes(status: 'declined', decision_note: 'Past the window')
      expect(payment.reload.refunds).to be_empty
    end

    it 'decides only once' do
      sign_in steward_user
      post decide_path(req), params: { outcome: 'approve' }

      expect { post decide_path(req), params: { outcome: 'approve' } }.not_to(change { payment.reload.refunds.count })
    end
  end
end
