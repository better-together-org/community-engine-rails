# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::WalkUpSalesController do
  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:path) { better_together.billing_walk_up_sale_path(locale:) }
  let(:new_path) { better_together.new_billing_walk_up_sale_path(locale:) }
  let(:cash_plan) do
    create(:better_together_billing_plan, :unlinked, processor: nil, accepted_payment_methods: %w[cash], billing_interval: 'one_time',
                                                     amount_cents: 4500, currency: 'USD')
  end
  let(:params) do
    { plan_id: cash_plan.id, payment_method: 'cash', buyer_id: buyer.id, buyer_email: 'notices@example.test', agreements_accepted: '1' }
  end

  before do
    enable_offline('cash')
    cash_plan
    purchase_agreements_for(host_platform)
    # The buyer is a member of the platform, with a role that does not manage anything.
    viewer = BetterTogether::Role.find_by!(identifier: 'platform_analytics_viewer')
    BetterTogether::PersonPlatformMembership.find_or_create_by!(member: buyer, joinable: host_platform, role: viewer) do |membership|
      membership.status = 'active'
    end
  end

  it 'sends a visitor to sign in' do
    get new_path

    expect(response).to have_http_status(:found)
  end

  it 'turns the buyer away' do
    sign_in buyer_user

    expect { post path, params: }.not_to change(BetterTogether::Billing::Order, :count)
  end

  context 'when signed in as a steward' do
    before { sign_in steward_user }

    it 'shows the form with stable ids' do
      get new_path

      expect(response.body).to include('billing-walk-up-form', 'billing-walk-up-plan', 'billing-walk-up-method', 'billing-walk-up-buyer',
                                       'billing-walk-up-agreements', 'billing-walk-up-received', 'billing-walk-up-submit')
    end

    it 'offers the person select for the buyer, searching the same members as the store credit screen' do
      get new_path

      expect(response.body).to include('better-together--slim-select', '/billing/people')
    end

    it 'keeps the chosen buyer on the form when the sale is refused' do
      post path, params: params.merge(agreements_accepted: '0')

      expect(response).to have_http_status(:unprocessable_content)
      expect(Nokogiri::HTML(response.body).at_css('#billing-walk-up-buyer option[selected]')['value']).to eq(buyer.id)
    end

    it 'says what is missing when there is nothing to sell or no method on' do
      host_platform.billing_processor_settings.update_all(enabled: false) # rubocop:disable Rails/SkipsModelValidations

      get new_path

      expect(response.body).to include('billing-walk-up-unavailable')
    end

    it 'places the order for the buyer, records the agreements as accepted in person, and leaves it waiting' do
      expect { post path, params: }.to change(BetterTogether::Billing::Order, :count).by(1)

      order = BetterTogether::Billing::Order.order(:created_at).last
      expect(response).to redirect_to(better_together.billing_sale_path(order, locale:))
      expect(order).to be_awaiting_payment
      expect(order.buyer).to eq(buyer)
      expect(order.offline_payments.first).to have_attributes(seller_assisted: true, status: 'awaiting')
      expect(order.agreement_acceptances.map(&:acceptance_method).uniq).to eq(['seller_assisted'])
    end

    it 'confirms the payment at once when the money has changed hands, and the buyer never had to do anything' do
      clear_notices
      deliver_now { post path, params: params.merge(payment_received: '1') }

      order = BetterTogether::Billing::Order.order(:created_at).last
      expect(order).to be_paid
      expect(order.offline_payments.first).to have_attributes(status: 'confirmed', claimed_at: nil, confirmed_by: steward)
      expect(kinds_for(buyer)).to include('payment_confirmed')
    end

    it 'asks for the buyer email, the name for a new buyer, and a complete address when one is started' do
      get new_path
      expect(response.body).to include('billing-walk-up-buyer-name', 'billing-walk-up-buyer-email', 'billing-walk-up-address')

      [params.merge(buyer_email: ''), params.merge(buyer_id: '', buyer_name: ''),
       params.merge(billing_address: { line1: '1 Water St' })].each do |attempts|
        expect { post path, params: attempts }.not_to change(BetterTogether::Billing::Order, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    it 'writes to the email given at the sale, for an existing buyer, and keeps it on the order' do
      clear_notices
      deliver_now { post path, params: params.merge(payment_received: '1') }

      order = BetterTogether::Billing::Order.order(:created_at).last
      expect(order.buyer_email).to eq('notices@example.test')
      expect(sent_mail.flat_map(&:to)).to include('notices@example.test')
      expect(sent_mail.flat_map(&:to)).not_to include(buyer.email)
    end

    it 'adds a buyer who is not on the platform: a person with that email, a member, invited to the community' do
      clear_notices
      unless BetterTogether::Role.exists?(identifier: 'platform_member')
        create(:better_together_role, :platform_role,
               identifier: 'platform_member')
      end
      unless BetterTogether::Role.exists?(identifier: 'community_member')
        create(:better_together_role, :community_role,
               identifier: 'community_member')
      end
      new_params = params.except(:buyer_id).merge(buyer_name: 'Odalys Fortier', buyer_email: 'Odalys@Example.test')

      expect { deliver_now { post path, params: new_params } }.to change(BetterTogether::Person, :count).by(1)

      order = BetterTogether::Billing::Order.order(:created_at).last
      person = order.buyer
      expect(person.name).to eq('Odalys Fortier')
      expect(person.email).to eq('odalys@example.test')
      expect(BetterTogether::PersonPlatformMembership.active.where(joinable: host_platform, member: person)).to exist
      invitation = BetterTogether::CommunityInvitation.find_by!(invitee: person)
      expect(invitation).to have_attributes(invitee_email: 'odalys@example.test', status: 'pending', inviter: steward)
      expect(sent_mail.flat_map(&:to)).to include('odalys@example.test')
    end

    it 'does not make a second person for an email that already belongs to one, and invites no one' do
      expect { post path, params: params.except(:buyer_id).merge(buyer_name: 'Someone', buyer_email: buyer.email) }
        .not_to change(BetterTogether::Person, :count)

      expect(BetterTogether::Billing::Order.order(:created_at).last.buyer).to eq(buyer)
      expect(BetterTogether::CommunityInvitation.count).to eq(0)
    end

    it 'invites no one and makes no one when the sale is refused' do
      refused = params.except(:buyer_id).merge(buyer_name: 'Odalys Fortier', buyer_email: 'o@example.test', agreements_accepted: '0')

      expect { post path, params: refused }.not_to change(BetterTogether::Person, :count)
    end

    it 'keeps the billing address on the order, and on the buyer when they have none' do
      address = { line1: '1 Water St', city_name: 'St. John\'s', state_province_name: 'NL', postal_code: 'A1C 1A1', country_name: 'Canada' }

      post path, params: params.merge(billing_address: address)

      order = BetterTogether::Billing::Order.order(:created_at).last
      expect(order.billing_address).to include('line1' => '1 Water St', 'country_name' => 'Canada')
      expect(buyer.reload.addresses.first).to have_attributes(line1: '1 Water St', postal: true)
    end

    it 'taxes the sale at the billing address, found by the country name and the province code' do
      country = create(:geography_country, name: 'Walkupland', iso_code: 'WU')
      create(:geography_state, country:, iso_code: 'WU-NL')

      allow(BetterTogether::Billing::Orders::Place).to receive(:call).and_call_original

      post path,
           params: params.merge(billing_address: { line1: '1 Water St', city_name: 'Town', state_province_name: 'nl',
                                                   country_name: 'Walkupland' })

      expect(BetterTogether::Billing::Orders::Place).to have_received(:call)
        .with(hash_including(tax_address: { country_iso: 'WU', region_code: 'NL' }))
    end

    it 'links a chosen country and state like the address form, copies their names, and taxes at them' do
      country = create(:geography_country, name: 'Linkland', iso_code: 'LK')
      state = create(:geography_state, country:, iso_code: 'LK-NL', name: 'Linkstate')
      allow(BetterTogether::Billing::Orders::Place).to receive(:call).and_call_original

      post path, params: params.merge(billing_address: { line1: '1 Water St', city_name: 'Town', country_id: country.id, state_id: state.id })

      order = BetterTogether::Billing::Order.order(:created_at).last
      expect(order.billing_address).to include('country_name' => 'Linkland', 'state_province_name' => 'Linkstate', 'country_id' => country.id)
      expect(buyer.reload.addresses.first).to have_attributes(country_id: country.id, state_id: state.id)
      expect(BetterTogether::Billing::Orders::Place).to have_received(:call)
        .with(hash_including(tax_address: { country_iso: 'LK', region_code: 'NL' }))
    end

    it 'refuses a state that is not in the chosen country' do
      country = create(:geography_country, name: 'Onel', iso_code: 'ON')
      other = create(:geography_state, country: create(:geography_country, name: 'Twol', iso_code: 'TW'), iso_code: 'TW-XX')

      expect do
        post path, params: params.merge(billing_address: { line1: '1 Water St', city_name: 'Town', country_id: country.id, state_id: other.id })
      end.not_to change(BetterTogether::Billing::Order, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'leaves a buyer\'s existing address alone' do
      detail = buyer.contact_detail || buyer.create_contact_detail!
      detail.addresses.create!(line1: 'Old Rd', city_name: 'Paradise', country_name: 'Canada', postal: true, physical: false, label: 'home')

      post path, params: params.merge(billing_address: { line1: '1 Water St', city_name: 'St. John\'s', country_name: 'Canada' })

      expect(buyer.reload.addresses.map(&:line1)).to eq(['Old Rd'])
    end

    it 'refuses without the agreements being accepted in person, and records nothing' do
      expect { post path, params: params.merge(agreements_accepted: '0') }.not_to change(BetterTogether::Billing::Order, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('billing-walk-up-error')
    end

    it 'refuses a buyer who is not a member of this platform, and one who does not exist' do
      stranger = create(:better_together_person)

      post path, params: params.merge(buyer_id: stranger.id)
      post path, params: params.merge(buyer_id: SecureRandom.uuid)

      expect(BetterTogether::Billing::Order.count).to eq(0)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'refuses a way of paying that is not switched on' do
      expect { post path, params: params.merge(payment_method: 'cheque') }.not_to change(BetterTogether::Billing::Order, :count)
    end

    it 'does not sell another platform\'s plan' do
      foreign = create(:better_together_billing_plan, platform: create(:better_together_platform))

      post path, params: params.merge(plan_id: foreign.id)

      expect(response).to have_http_status(:not_found)
    end
  end
end
