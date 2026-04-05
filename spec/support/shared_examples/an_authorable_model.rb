# frozen_string_literal: true

RSpec.shared_examples 'an authorable model' do
  it 'has identity in its ancestor tree' do
    expect(described_class.ancestors).to include(
      BetterTogether::Authorable
    )
  end

  describe 'ActiveRecord associations' do
    it { is_expected.to have_many(:authorships) }
    it { is_expected.to have_many(:authors).through(:contributions) }
    it { is_expected.to have_many(:robot_authors).through(:contributions) }
  end
end
