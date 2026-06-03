# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Uploads' do
  let(:locale) { I18n.default_locale }
  let(:user) { find_or_create_test_user('upload-reviewer@example.test', 'SecureTest123!@#') }
  let!(:upload) { create(:better_together_upload, creator: user.person, name: 'Held upload') }

  before do
    upload.file.attach(io: StringIO.new('held upload'), filename: 'held.txt', content_type: 'text/plain')
    upload.save!
    sign_in user
  end

  it 'shows held-review status and disables insert actions for pending uploads' do
    get better_together.file_index_path(locale:)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Under review')
    expect(response.body).to include('reviewed before it can be inserted into rich text or shared')
    expect(response.body).to include('disabled')
  end
end
