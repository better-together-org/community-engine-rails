# frozen_string_literal: true

RSpec.shared_examples 'an identity' do
  it 'has identity in its ancestor tree' do
    expect(described_class.ancestors).to include(
      BetterTogether::Identity
    )
  end

  describe 'ActiveRecord associations' do
    it { is_expected.to have_many(:identifications) }
  end
end
