# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::AgreementResolver do
  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'

  let(:community) { create(:better_together_community) }

  # Starts from an empty set of requirements, then builds the ones a spec needs.
  before { host_platform.billing_agreement_requirements.destroy_all }

  def agreement(name) = create(:better_together_agreement, agreement_kind: 'transactional_agreement', platform: host_platform, identifier: name)

  def require_agreement(name, **attrs)
    host_platform.billing_agreement_requirements.create!({ agreement: agreement(name), mode: 'additional' }.merge(attrs))
  end

  def resolve(**attrs)
    described_class.call(platform: host_platform, purpose: 'one_time', purchasables: [plan], **attrs)
  end

  def identifiers(resolution) = resolution.agreements.map(&:identifier)

  it 'applies the platform\'s default terms to everything' do
    require_agreement('default-terms')

    expect(identifiers(resolve)).to eq(['default-terms'])
    expect(resolve).to be_base_terms
  end

  it 'applies a default only to the kind of purchase it is for' do
    require_agreement('subscription-terms', purpose: 'subscription')
    require_agreement('any-terms')

    expect(identifiers(resolve(purpose: 'one_time'))).to eq(['any-terms'])
    expect(identifiers(resolve(purpose: 'subscription'))).to contain_exactly('any-terms', 'subscription-terms')
  end

  it 'adds terms narrowed to the product after the default ones' do
    require_agreement('default-terms')
    require_agreement('plan-terms', target: plan)

    expect(identifiers(resolve)).to eq(%w[default-terms plan-terms])
  end

  it 'adds a seller\'s terms between the platform\'s and the product\'s' do
    require_agreement('default-terms')
    require_agreement('plan-terms', target: plan)
    require_agreement('seller-terms', target: community)

    expect(identifiers(resolve(seller: community))).to eq(%w[default-terms seller-terms plan-terms])
  end

  it 'does not apply terms narrowed to a different product or seller' do
    other_plan = create(:better_together_billing_plan)
    require_agreement('default-terms')
    require_agreement('other-plan-terms', target: other_plan)
    require_agreement('other-seller-terms', target: community)

    expect(identifiers(resolve)).to eq(['default-terms'])
  end

  it 'lets a narrower requirement replace the defaults' do
    require_agreement('default-terms')
    require_agreement('our-terms', target: plan, mode: 'replaces_default')

    expect(identifiers(resolve)).to eq(['our-terms'])
  end

  it 'does not let a requirement that adds remove the defaults' do
    require_agreement('default-terms')
    require_agreement('extra-terms', target: plan, mode: 'additional')

    expect(identifiers(resolve)).to eq(%w[default-terms extra-terms])
  end

  it 'adds the terms that come with a payment method last, and never replaces them' do
    require_agreement('default-terms')
    require_agreement('cash-terms', payment_method: 'cash')
    require_agreement('our-terms', target: plan, mode: 'replaces_default')

    expect(identifiers(resolve(payment_method: 'cash'))).to eq(%w[our-terms cash-terms])
    expect(identifiers(resolve(payment_method: 'cheque'))).to eq(['our-terms'])
    expect(identifiers(resolve)).to eq(['our-terms'])
  end

  it 'does not count a payment method\'s terms as a purchase agreement' do
    require_agreement('cash-terms', payment_method: 'cash')

    expect(resolve(payment_method: 'cash')).not_to be_base_terms
  end

  it 'lists an agreement once, however many requirements name it' do
    shared = agreement('shared-terms')
    host_platform.billing_agreement_requirements.create!(agreement: shared, mode: 'additional')
    host_platform.billing_agreement_requirements.create!(agreement: shared, mode: 'additional', target: plan)

    expect(identifiers(resolve)).to eq(['shared-terms'])
  end

  it 'orders terms of the same level by position' do
    require_agreement('second', position: 2)
    require_agreement('first', position: 1)

    expect(identifiers(resolve)).to eq(%w[first second])
  end

  it 'never reads another platform\'s requirements' do
    other = create(:better_together_platform)
    foreign = create(:better_together_agreement, agreement_kind: 'transactional_agreement', platform: other, identifier: 'foreign-terms')
    other.billing_agreement_requirements.create!(agreement: foreign, mode: 'additional')

    expect(identifiers(resolve)).to be_empty
    expect(resolve).not_to be_base_terms
  end
end
