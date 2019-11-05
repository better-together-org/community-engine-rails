
RSpec.shared_examples 'an identity' do

  it 'has identity in its ancestor tree' do
    expect(described_class.ancestors).to include(
      BetterTogether::Community::Identity
    )
  end

  describe 'ActiveRecord associations' do
    it { is_expected.to have_many(:identifications) }
    it { is_expected.to have_many(:agents) }
  end
end
