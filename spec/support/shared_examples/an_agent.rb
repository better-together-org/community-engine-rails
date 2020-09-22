# frozen_string_literal: true

RSpec.shared_examples 'an agent' do
  it 'has Agent in its ancestor tree' do
    expect(described_class.ancestors).to include(
      BetterTogether::Agent
    )
  end

  describe 'ActiveRecord associations' do
    it { is_expected.to have_many(:identifications) }
    # it { is_expected.to have_many(:identities) }
  end

  describe '#active_identity' do
    it { is_expected.to respond_to :active_identity }
  end
end
