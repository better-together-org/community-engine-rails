# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PersonAccessGrant feature gate enforcement', :no_auth do
  let(:locale) { I18n.default_locale }
  let(:password) { 'SecureTest123!@#' }
  let(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host) }
  let(:grant) { create(:better_together_person_access_grant) }
  let(:grantor_person) { grant.grantor_person }
  let(:grantor_user) { create(:better_together_user, :confirmed, person: grantor_person, password:) }

  before do
    platform.update!(feature_gate_rollouts: { 'person_access_grants' => 'off' })
  end

  it 'blocks direct access when the feature rollout is disabled' do
    login(grantor_user.email, password)

    get better_together.person_access_grants_path(locale:)

    expect(response).to redirect_to(better_together.home_page_path(locale:))
    expect(flash[:error]).to be_present
  end
end
