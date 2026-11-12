# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BillingAgreementLeakReset do
  it 'puts a committed active transactional agreement back to draft' do
    agreement = create(:better_together_agreement, agreement_kind: 'transactional_agreement', lifecycle_state: 'active')

    described_class.call

    expect(agreement.reload.lifecycle_state).to eq('draft')
  end

  it 'leaves agreements that are not transactional alone' do
    agreement = create(:better_together_agreement, agreement_kind: 'policy_consent', lifecycle_state: 'active')

    described_class.call

    expect(agreement.reload.lifecycle_state).to eq('active')
  end
end
