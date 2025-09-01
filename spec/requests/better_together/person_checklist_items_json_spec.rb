require 'rails_helper'

RSpec.describe 'PersonChecklistItems JSON', :as_user do
  let(:checklist) { create(:better_together_checklist) }
  let(:item) { create(:better_together_checklist_item, checklist: checklist) }

  it 'accepts JSON POST with headers and returns json' do
    url = better_together.create_person_checklist_item_checklist_checklist_item_path(
      locale: I18n.default_locale,
      checklist_id: checklist.id,
      id: item.id
    )
    headers = { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json',
                'X-Requested-With' => 'XMLHttpRequest' }
    post url, params: { completed: true }.to_json, headers: headers
    puts "DEBUG RESPONSE STATUS: #{response.status}"
    puts "DEBUG RESPONSE BODY: #{response.body}"
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body['completed_at']).not_to be_nil
  # New: server includes a flash payload in JSON for client-side display
  expect(body['flash']).to be_present
  expect(body['flash']['type']).to eq('notice')
  expect(body['flash']['message']).to eq(I18n.t('flash.checklist_item.updated'))
  end
end
