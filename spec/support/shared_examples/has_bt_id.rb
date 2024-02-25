# frozen_string_literal: true

RSpec.shared_examples 'has_id' do
  it 'has BetterTogetherID in its ancestor tree' do
    expect(described_class.ancestors).to include(
      BetterTogether::BetterTogetherId
    )
  end

  describe 'callbacks' do
    it { is_expected.to callback(:generate_id).before(:validation) }
  end
end
