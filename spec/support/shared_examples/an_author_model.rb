
RSpec.shared_examples 'an author model' do

  it 'has identity in its ancestor tree' do
    expect(described_class.ancestors).to include(
      BetterTogether::AuthorConcern
    )
  end

  describe 'ActiveRecord associations' do
    it { is_expected.to have_many(:authorships) }
    it { is_expected.to have_many(:authorables).through(:authorships) }
  end
end
