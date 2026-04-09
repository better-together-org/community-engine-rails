# frozen_string_literal: true

require 'rails_helper'
require 'stringio'

RSpec.describe 'BetterTogether::PostsController', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let(:platform_manager) { BetterTogether::User.find_by(email: 'manager@example.test') }
  let!(:category) { create(:category) }
  let!(:post_record) do
    create(
      :better_together_post,
      author: platform_manager.person,
      creator: platform_manager.person,
      privacy: 'public'
    )
  end

  before do
    post_record.categories << category
    category.cover_image.attach(
      io: StringIO.new('<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>'),
      filename: 'cover.svg',
      content_type: 'image/svg+xml'
    )
    post_record.add_governed_contributor(platform_manager.person, role: 'editor')
  end

  it 'preloads post card associations for index rendering', :aggregate_failures do
    get better_together.posts_path(locale:)

    expect(response).to have_http_status(:ok)
    loaded_post = assigns(:posts).find { |post| post.id == post_record.id }

    expect(loaded_post.association(:string_translations)).to be_loaded
    expect(loaded_post.association(:cover_image_attachment)).to be_loaded
    expect(loaded_post.association(:contributions)).to be_loaded
    expect(loaded_post.association(:categories)).to be_loaded
    expect(loaded_post.categories.first.association(:cover_image_attachment)).to be_loaded

    rich_text_association = loaded_post.class.reflect_on_association(:rich_text_content)&.name
    expect(loaded_post.association(rich_text_association)).to be_loaded if rich_text_association
  end
end
