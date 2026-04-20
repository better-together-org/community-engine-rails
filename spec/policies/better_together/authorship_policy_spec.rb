# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::AuthorshipPolicy, type: :policy do
  describe 'scope' do
    let!(:authorship) do
      page = create(:better_together_page)
      author = create(:better_together_person)
      BetterTogether::Authorship.create!(author:, authorable: page, role: 'author', contribution_type: 'documentation')
    end
    let(:person) { instance_double(BetterTogether::Person) }
    let(:user) { instance_double(BetterTogether::User, person:) }

    before do
      allow(person).to receive(:permitted_to?).with('manage_platform_settings').and_return(true)
      allow(person).to receive(:permitted_to?).with('manage_platform').and_return(false)
    end

    it 'includes authorships for platform settings managers' do
      resolved = described_class::Scope.new(user, BetterTogether::Authorship.all).resolve

      expect(resolved).to include(authorship)
    end
  end
end
