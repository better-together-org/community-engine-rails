# frozen_string_literal: true

require 'rails_helper'

# A steward gives a person store credit.
RSpec.describe BetterTogether::Billing::CreditGrantsController do
  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }

  def grants_path = better_together.billing_credit_grants_path(locale:)

  def params_for(holder = buyer, **overrides)
    { person_id: holder.id, token: 'form-1', amount: '25.00', currency: 'USD' }.merge(overrides)
  end

  def account_for(holder = buyer) = host_platform.billing_credit_accounts.find_by(holder:, currency: 'USD')

  it 'sends a visitor to sign in' do
    post grants_path, params: params_for

    expect(response).to have_http_status(:found)
    expect(account_for).to be_nil
  end

  it 'turns a signed-in non-steward away' do
    sign_in buyer_user

    post grants_path, params: params_for(other_buyer)

    expect(account_for(other_buyer)).to be_nil
  end

  context 'when signed in as a steward' do
    before { sign_in steward_user }

    it 'gives credit, recorded with who gave it and why, and shows the account' do
      post grants_path, params: params_for(note: 'Volunteer thanks', expires_in_days: '30')

      account = account_for
      expect(response).to redirect_to(better_together.billing_credit_account_path(account, locale:))
      expect(account.balance_cents).to eq(2500)
      lot = account.lots.sole
      expect(lot).to have_attributes(origin: 'steward_grant', granted_by: steward, note: 'Volunteer thanks')
      expect(lot.expires_at).to be_within(1.minute).of(30.days.from_now)
      expect(account.entries.sole).to have_attributes(kind: 'grant', actor: steward)
    end

    it 'gives credit that does not expire when no days are given' do
      post grants_path, params: params_for

      expect(account_for.lots.sole.expires_at).to be_nil
    end

    it 'tells the person, and not the steward' do
      clear_notices
      deliver_now { post grants_path, params: params_for }

      expect(kinds_for(buyer)).to include('credit_granted')
      expect(kinds_for(steward)).not_to include('credit_granted')
    end

    it 'gives it once when the form is sent twice' do
      2.times { post grants_path, params: params_for }

      expect(account_for.balance_cents).to eq(2500)
      expect(account_for.entries.count).to eq(1)
    end

    it 'refuses a grant sent without its form token' do
      expect { post grants_path, params: params_for(token: '') }.not_to change(BetterTogether::Billing::CreditEntry, :count)
    end

    it 'gives it again for a new form' do
      post grants_path, params: params_for(token: 'a')
      post grants_path, params: params_for(token: 'b')

      expect(account_for.balance_cents).to eq(5000)
    end

    it 'never lets a steward give themselves credit' do
      post grants_path, params: params_for(steward)

      expect(response).to redirect_to(better_together.billing_credit_accounts_path(locale:, person_id: steward.id))
      expect(account_for(steward)).to be_nil
    end

    it 'refuses an amount that is not a plain positive number, a currency that is not supported, and a person that does not exist' do
      [{ amount: '' }, { amount: '-5' }, { amount: '0' }, { amount: 'ten' }, { currency: 'XXX' }, { person_id: SecureRandom.uuid }].each do |bad|
        post grants_path, params: params_for(**bad)

        expect(response).to have_http_status(:found)
      end
      expect(account_for).to be_nil
    end
  end
end
