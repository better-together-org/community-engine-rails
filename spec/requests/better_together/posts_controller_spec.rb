# frozen_string_literal: true

require 'rails_helper'
require 'stringio'

# rubocop:todo RSpec/MultipleDescribes
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
    # The PrivacyCeilingValidatable concern prevents public posts in private communities,
    # so test scenarios use valid combinations: public posts in public communities and
    # community-privacy posts (valid in any community since members can share within them).
    let!(:other_community) do
      # A separate public community on the same platform — tests cross-community visibility.
      create(:better_together_community, privacy: 'public')
    end
    let!(:public_post) do
      create(:better_together_post, title: 'Public Post In Other Community',
                                    community: other_community, platform: host_platform,
                                    privacy: 'public', published_at: 1.day.ago)
    end
    let!(:community_post) do
      create(:better_together_post, title: 'Community Post In Other Community',
                                    community: other_community, platform: host_platform,
                                    privacy: 'community', published_at: 1.day.ago)
    end

    before { configure_host_platform }

    # Post privacy is the authoritative visibility gate.
    # Community privacy controls membership access, not individual post visibility.
    it 'shows all public posts to guests regardless of which community they belong to', :no_auth do
      logout
      get better_together.posts_path(locale:)

      expect(response).to have_http_status(:ok)
      expect_html_content('Public Post In Other Community')
      expect_no_html_content('Community Post In Other Community')
    end

    context 'as a platform community member', :no_auth do
      let(:regular_user) { find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user) }

      before do
        configure_host_platform
        # Referencing regular_user before login forces find_or_create_test_user to run
        # first — login() requires the user to already exist and be confirmed.
        regular_user
        login('user@example.test', 'SecureTest123!@#')
        # PostPolicy::Scope's scoped_community_privacy_query filters community-privacy
        # posts by post.community_id (not platform membership) — the user must be a
        # member of the post's own community (other_community here), not host_community.
        create(:better_together_person_community_membership,
               member: regular_user.person,
               joinable: other_community,
               status: 'active')
      end

      it 'sees community-privacy posts in communities they are a member of' do
        get better_together.posts_path(locale:)

        expect(response).to have_http_status(:ok)
        expect_html_contents('Public Post In Other Community', 'Community Post In Other Community')
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

  it 'renders the federation_visibility field on edit' do
    get better_together.edit_post_path(post_record, locale:)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('post[federation_visibility]')
  end

  it 'renders a per-connection grant row for each active connection allowing posts' do
    connection = create(:better_together_platform_connection, :active, :sharing_enabled)

    get better_together.edit_post_path(post_record, locale:)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("post[federation_content_grants_by_connection][#{connection.id}]")
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

    it 'persists an explicit federation_visibility override on update' do
      patch better_together.post_path(post_record, locale:), params: {
        post: {
          title_en: post_record.title,
          content_en: post_record.content.to_plain_text,
          privacy: 'public',
          federation_visibility: 'no_federate'
        }
      }

      expect(response).to be_redirect
      expect(post_record.reload).to be_federation_visibility_no_federate
    end

    it 'persists a per-connection federation grant on update' do
      connection = create(:better_together_platform_connection, :active, :sharing_enabled)

      patch better_together.post_path(post_record, locale:), params: {
        post: {
          title_en: post_record.title,
          content_en: post_record.content.to_plain_text,
          privacy: 'public',
          federation_content_grants_by_connection: { connection.id => 'denied' }
        }
      }

      expect(response).to be_redirect
      expect(post_record.reload.federation_grant_status_for(connection)).to eq('denied')
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

RSpec.describe 'BetterTogether::PostsController self-service publishing agreement gate' do
  let(:locale) { I18n.default_locale }
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:host_community) { host_platform.community }
  let(:member_role) { BetterTogether::Role.find_by(identifier: 'community_member') }
  let(:member_user) { create(:better_together_user, :confirmed) }

  before do
    BetterTogether::PersonCommunityMembership.create!(
      joinable: host_community, member: member_user.person, role: member_role, status: 'active'
    )
    login(member_user.email, 'SecureTest123!@#')
  end

  it 'redirects GET new to the publishing agreement page when the member has not accepted it' do
    get better_together.new_post_path(locale:, community_id: host_community.id)

    expect(response).to redirect_to(%r{/agreements/})
  end

  it 'allows the member to create a post once the agreement is accepted' do
    grant_content_publishing_agreement(member_user.person)

    expect do
      post better_together.posts_path(locale:), params: {
        post: { title_en: 'Member Post', content_en: 'Written by a self-service member', privacy: 'private',
                community_id: host_community.id }
      }
    end.to change(BetterTogether::Post, :count).by(1)
  end
end

RSpec.describe 'BetterTogether::PostsController self-service gate platform manager bypass', :as_platform_manager do
  let(:locale) { I18n.default_locale }

  it 'GET new succeeds for a platform manager without any agreement acceptance' do
    get better_together.new_post_path(locale:)

    expect(response).to have_http_status(:ok)
  end
end
# rubocop:enable RSpec/MultipleDescribes
