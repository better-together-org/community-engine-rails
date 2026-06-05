# frozen_string_literal: true

require 'rails_helper'
require 'stringio'

RSpec.describe 'BetterTogether::PostsController', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let(:platform_manager) { BetterTogether::User.find_by(email: 'manager@example.test') }
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:host_community) { host_platform.community }
  let!(:category) { create(:category) }
  let!(:post_record) do
    unique_token = SecureRandom.hex(4)
    create(
      :better_together_post,
      author: platform_manager.person,
      creator: platform_manager.person,
      community: host_community,
      platform: host_platform,
      privacy: 'public',
      published_at: 1.day.ago,
      slug: "contribution-post-#{unique_token}",
      identifier: "contribution-post-#{unique_token}"
    )
  end

  before do
    host_community.update!(privacy: 'public')
    post_record.categories << category
    category.cover_image.attach(
      io: StringIO.new('<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>'),
      filename: 'cover.svg',
      content_type: 'image/svg+xml'
    )
    post_record.add_governed_contributor(platform_manager.person, role: 'editor')
  end

  describe 'community scoping' do
    let!(:private_community) do
      create(:better_together_community, privacy: 'private')
    end

    before do
      configure_host_platform
      host_community.update!(privacy: 'public')

      create(
        :better_together_post,
        title: 'Host Community Post',
        community: host_community,
        platform: host_platform,
        privacy: 'public',
        published_at: 1.day.ago
      )

      create(
        :better_together_post,
        title: 'Private Community Post',
        community: private_community,
        platform: host_platform,
        privacy: 'public',
        published_at: 1.day.ago
      )
    end

    it 'shows only public community posts for guests', :no_auth do
      logout

      get better_together.posts_path(locale:)

      expect(response).to have_http_status(:ok)
      expect_html_content('Host Community Post')
      expect_no_html_content('Private Community Post')
    end

    context 'as a community member', :no_auth do
      let(:regular_user) { find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user) }

      before do
        configure_host_platform
        login('user@example.test', 'SecureTest123!@#')
        create(:better_together_person_community_membership,
               member: regular_user.person,
               joinable: private_community,
               status: 'active')
      end

      it 'includes private community posts for members' do
        get better_together.posts_path(locale:)

        expect(response).to have_http_status(:ok)
        expect_html_contents('Host Community Post', 'Private Community Post')
      end
    end
  end

  it 'renders not found for guests requesting a private unpublished post' do
    hidden_post = create(
      :better_together_post,
      author: platform_manager.person,
      creator: platform_manager.person,
      privacy: 'private',
      published_at: nil,
      slug: "hidden-post-#{SecureRandom.hex(4)}",
      identifier: "hidden-post-#{SecureRandom.hex(4)}"
    )

    logout

    get better_together.post_path(hidden_post, locale:)

    expect(response).to have_http_status(:not_found)
  end

  it 'renders a private unpublished post for its creator' do
    hidden_post = create(
      :better_together_post,
      author: platform_manager.person,
      creator: platform_manager.person,
      privacy: 'private',
      published_at: nil,
      title: 'Creator Hidden Post',
      slug: "creator-hidden-post-#{SecureRandom.hex(4)}",
      identifier: "creator-hidden-post-#{SecureRandom.hex(4)}"
    )

    get better_together.post_path(hidden_post, locale:)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Creator Hidden Post')
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

  describe 'guest view switching', :no_auth do
    before do
      logout
    end

    it 'defaults to card view' do
      get better_together.posts_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('row-cols-md-2')
      expect(response.body).to include('data-turbo-prefetch="false"')
    end

    it 'renders table view when preference is set' do
      post better_together.view_preferences_path(locale:),
           params: { key: 'index_view', view_type: 'table', allowed: %w[card table list calendar map] },
           headers: { 'HTTP_REFERER' => better_together.posts_path(locale:) }

      get better_together.posts_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('posts-table')
      expect(response.body).not_to include('posts-list')
    end

    it 'renders list view when preference is set' do
      post better_together.view_preferences_path(locale:),
           params: { key: 'index_view', view_type: 'list', allowed: %w[card table list calendar map] },
           headers: { 'HTTP_REFERER' => better_together.posts_path(locale:) }

      get better_together.posts_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('posts-list')
      expect(response.body).not_to include('posts-table')
    end
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

  it 'hides post contributor bylines on public views when the platform default is off' do
    logout
    post_record.platform.update!(contributors_display_visibility: 'off')

    get better_together.post_path(post_record, locale:)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(platform_manager.person.name)
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

  it 'renders the contributor display visibility field on edit' do
    get better_together.edit_post_path(post_record, locale:)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('post[contributors_display_visibility]')
  end

  describe 'manager CRUD flows' do
    it 'creates a post' do
      expect do
        post better_together.posts_path(locale:), params: {
          post: {
            title_en: 'Coverage Created Post',
            content_en: 'Created during CRUD coverage',
            privacy: 'private',
            category_ids: [category.id]
          }
        }
      end.to change(BetterTogether::Post, :count).by(1)

      created_post = BetterTogether::Post.order(:created_at).last
      expect(response).to redirect_to(better_together.post_path(created_post, locale:))
      expect(created_post.title).to eq('Coverage Created Post')
    end

    it 'renders new when create params are invalid', :aggregate_failures do
      expect do
        post better_together.posts_path(locale:), params: {
          post: {
            title_en: '',
            content_en: '',
            privacy: 'private'
          }
        }
      end.not_to change(BetterTogether::Post, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'updates an existing post', :aggregate_failures do
      patch better_together.post_path(post_record, locale:), params: {
        post: {
          title_en: 'Updated Coverage Post',
          content_en: 'Updated coverage body',
          privacy: 'private',
          contributors_display_visibility: 'off'
        }
      }

      expect(response).to be_redirect
      expect(post_record.reload.title).to eq('Updated Coverage Post')
      expect(post_record.reload.content.to_plain_text).to include('Updated coverage body')
    end

    it 'renders edit when update params are invalid', :aggregate_failures do
      patch better_together.post_path(post_record, locale:), params: {
        post: {
          title_en: '',
          content_en: ''
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(post_record.reload.title).not_to be_blank
    end

    it 'destroys an unprotected post' do
      doomed_post = create(:better_together_post, creator: platform_manager.person, author: platform_manager.person)

      expect do
        delete better_together.post_path(doomed_post, locale:)
      end.to change(BetterTogether::Post, :count).by(-1)
    end
  end
end
