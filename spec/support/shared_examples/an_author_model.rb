# frozen_string_literal: true

RSpec.shared_examples 'an author model' do
  it 'has identity in its ancestor tree' do
    expect(described_class.ancestors).to include(
      BetterTogether::Author
    )
  end

  describe 'ActiveRecord associations' do
    it { is_expected.to have_many(:authorships) }
    # Todo for each thing they can author, define a relationship.
    # Should be established in authorable concern I guess!
    # it { is_expected.to have_many(:authorables).through(:authorships) }
  end
end
