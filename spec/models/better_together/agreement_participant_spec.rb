# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::AgreementParticipant do
  subject(:participant) { create(:better_together_agreement_participant, agreement:, person:) }

  let(:agreement) { create(:better_together_agreement) }
  let(:person) { create(:better_together_person) }

  it { is_expected.to belong_to(:agreement).class_name('BetterTogether::Agreement') }
  it { is_expected.to belong_to(:person).class_name('BetterTogether::Person') }

  it 'has a valid factory' do
    expect(participant).to be_valid
  end
end
