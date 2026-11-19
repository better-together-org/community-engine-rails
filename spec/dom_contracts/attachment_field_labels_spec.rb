# frozen_string_literal: true

require 'rails_helper'

# Every attachment field partial must associate its label with the file input,
# otherwise assistive tech announces an unlabelled control.
RSpec.describe 'Attachment field label association DOM contract', :as_platform_manager, type: :request do # rubocop:disable RSpec/DescribeClass
  def expect_label_for_input(input_id)
    doc = Nokogiri::HTML(response.body)
    counts = [doc.css("input[type=file]##{input_id}"), doc.css("label[for='#{input_id}']"),
              doc.css("[id='#{input_id}']")].map(&:size)
    expect(counts).to eq([1, 1, 1])
  end

  it 'associates the cover image label with its file input on the post form', :aggregate_failures do
    post_record = create(:better_together_post)
    get "/#{I18n.default_locale}/posts/#{post_record.slug}/edit"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="cover-image-fields"')
    expect_label_for_input('cover-image-input')
  end

  it 'associates the feature image label with its file input on the page form', :aggregate_failures do
    page_record = create(:better_together_page)
    get "/#{I18n.default_locale}/pages/#{page_record.slug}/edit"

    expect(response).to have_http_status(:ok)
    expect_label_for_input('feature-image-input')
  end
end
