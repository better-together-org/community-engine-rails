# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Person profile contact detail privacy', :as_user do
  let(:locale) { I18n.default_locale }
  let(:owner) { create(:better_together_user, :confirmed).person }
  let(:contact_detail) { owner.contact_detail.reload }

  before do
    owner.update_column(:privacy, 'public') # rubocop:disable Rails/SkipsModelValidations
    create(:email_address, contact_detail:, email: 'shown-contact@example.test', privacy: 'public',
                           primary_flag: false, label: 'personal')
    create(:email_address, contact_detail:, email: 'hidden-contact@example.test', privacy: 'private',
                           primary_flag: false, label: 'work')
  end

  def profile_path
    better_together.person_path(locale:, id: owner.slug)
  end

  it 'hides private contact items from other viewers', :aggregate_failures do
    get profile_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('shown-contact@example.test')
    expect(response.body).not_to include('hidden-contact@example.test')
  end

  it 'hides private contact items from signed-out viewers', :aggregate_failures, :no_auth do
    get profile_path

    expect(response.body).to include('shown-contact@example.test')
    expect(response.body).not_to include('hidden-contact@example.test')
  end

  context 'when the owner views their own profile' do
    let(:owner) { BetterTogether::User.find_by!(email: 'user@example.test').person }

    it 'shows private contact items', :aggregate_failures do
      get profile_path

      expect(response.body).to include('shown-contact@example.test')
      expect(response.body).to include('hidden-contact@example.test')
    end
  end
end
