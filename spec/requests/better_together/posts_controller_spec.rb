# frozen_string_literal: true

require 'rails_helper'
require 'stringio'

RSpec.describe 'BetterTogether::PostsController', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let(:platform_manager) { BetterTogether::User.find_by(email: 'manager@example.test') }
  let!(:category) { create(:category) }
  let!(:post_record) do
    unique_token = SecureRandom.hex(4)
    create(
      :better_together_post,
      author: platform_manager.person,
      creator: platform_manager.person,
      privacy: 'public',
      slug: "contribution-post-#{unique_token}",
      identifier: "contribution-post-#{unique_token}"
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

  it 'keeps contribution and evidence references out of the public show page' do
    citation = create(:citation, citeable: post_record, title: 'Post review notes', reference_key: 'post-review-notes')
    claim = create(:claim, claimable: post_record, statement: 'This post was reviewed against the release checklist.')
    create(:evidence_link, claim:, citation:, relation_type: 'supports')
    post_record.contributions.first.update!(details: {
                                              'github_handle' => 'post-maintainer',
                                              'github_sources' => [{ 'reference_key' => 'pull_request_1494' }]
                                            })

    get better_together.post_path(post_record, locale:)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(platform_manager.person.name)
    expect(response.body).not_to include('Contributors:')
    expect(response.body).not_to include('GitHub-linked')
    expect(response.body).not_to include('Claims and Supporting Evidence')
    expect(response.body).not_to include('Evidence and Citations')
    expect(response.body).not_to include('Post review notes')
  end

  it 'renders the unified governed contributions form section on edit' do
    get better_together.edit_post_path(post_record, locale:)

    expect(response).to have_http_status(:ok)
    doc = Nokogiri::HTML.parse(response.body)
    section = doc.at_css('[data-controller="better_together--contribution-assignments"]')
    container = doc.at_css('[data-better_together--contribution-assignments-target="container"].row.g-3')
    entry = doc.at_css('[data-better_together--contribution-assignments-target="entry"].col-12.col-lg-6.nested-fields')

    expect(section).to be_present
    expect(container).to be_present
    expect(entry).to be_present
    expect(response.body).to include('post[contributions_attributes]')
    expect(response.body).not_to include('post[author_ids]')
    expect(response.body).not_to include('post[editor_ids]')
  end
end
