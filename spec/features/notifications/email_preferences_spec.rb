# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'email notification preferences' do
  let(:user) { create(:user, :confirmed) }

  before do
    sign_in_user(user.email, user.password)
  end

  it 'is enabled by default' do
    visit edit_person_path(id: 'me', locale: I18n.default_locale)
    expect(page).to have_checked_field 'person[notify_by_email]'
  end

  it 'is disabled on the instance model when unchecked on the form' do
    visit edit_person_path(id: 'me', locale: I18n.default_locale)
    uncheck 'person[notify_by_email]'
    click_button 'commit'
    # Reload the edit page and verify the toggle is now unchecked
    visit edit_person_path(id: 'me', locale: I18n.default_locale)
    expect(page).to have_unchecked_field 'person[notify_by_email]'
  end
end
