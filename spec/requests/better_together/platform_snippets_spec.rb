# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Platform snippets', :no_auth do # rubocop:disable RSpec/DescribeClass
  include AutomaticTestConfiguration

  let(:locale) { I18n.default_locale }
  let(:platform) { configure_host_platform }
  let(:page_path) { better_together.new_user_session_path(locale:) }
  let(:code_manager) { user_with_role('code-manager@example.test', 'platform_code_manager') }
  let(:steward) { user_with_role('code-steward@example.test', 'platform_steward') }

  def user_with_role(email, identifier)
    user = find_or_create_test_user(email, 'SecureTest123!@#', :user)
    role = BetterTogether::Role.find_by!(identifier:)
    platform.person_platform_memberships.find_or_create_by!(member: user.person, role:, status: 'active')
    user
  end

  def snippet!(**attrs)
    BetterTogether::PlatformSnippet.create!({ platform:, name: 'S', location: 'head_end', kind: 'script_inline',
                                              content: 'window.snippetRan = true;', enabled: true }.merge(attrs))
  end

  describe 'layout injection' do
    it 'renders an enabled inline script with the request CSP nonce' do # rubocop:disable RSpec/MultipleExpectations
      snippet!
      get page_path
      nonce = response.headers['Content-Security-Policy'][/script-src[^;]*'nonce-([^']+)'/, 1]

      expect(nonce).to be_present
      expect(response.body).to include(%(<script nonce="#{nonce}" data-platform-snippet=))
      expect(response.body).to include('window.snippetRan = true;')
    end

    it 'places each snippet at its location' do # rubocop:disable RSpec/MultipleExpectations
      snippet!(name: 'a', content: 'headEnd()')
      snippet!(name: 'b', location: 'head_start', content: 'headStart()')
      snippet!(name: 'c', location: 'body_start', content: 'bodyStart()')
      snippet!(name: 'd', location: 'body_end', content: 'bodyEnd()')
      get page_path
      body = response.body

      expect(body.index('headStart()')).to be < body.index('headEnd()')
      expect(body.index('headEnd()')).to be < body.index('</head>')
      expect(body.index('</head>')).to be < body.index('bodyStart()')
      expect(body.index('bodyStart()')).to be < body.index('bodyEnd()')
    end

    it 'skips disabled snippets, other platforms and consent-gated categories' do # rubocop:disable RSpec/MultipleExpectations
      snippet!(content: 'disabledOne()', enabled: false)
      snippet!(content: 'analyticsOne()', consent_category: 'analytics')
      other = create(:better_together_platform)
      BetterTogether::PlatformSnippet.create!(platform: other, name: 'o', location: 'head_end', kind: 'script_inline',
                                              content: 'otherPlatform()', enabled: true)
      get page_path

      expect(response.body).not_to include('disabledOne()', 'analyticsOne()', 'otherPlatform()')
    end

    it 'is switched off by the platform kill switch' do
      snippet!
      platform.update!(snippets_enabled: false)
      get page_path

      expect(response.body).not_to include('snippetRan')
    end

    it 'honours safe mode only for people who manage code' do # rubocop:disable RSpec/MultipleExpectations
      snippet!
      get "#{page_path}?safe_mode=1"
      expect(response.body).to include('snippetRan')

      sign_in code_manager
      get "#{page_path}?safe_mode=1"
      expect(response.body).not_to include('snippetRan')
    end

    it 'hides signed-out-only snippets from signed-in people' do
      snippet!(applies_to: 'signed_out')
      sign_in steward
      get page_path

      expect(response.body).not_to include('snippetRan')
    end

    it 'fails open when a snippet cannot render' do # rubocop:disable RSpec/MultipleExpectations
      snippet!(name: 'meta', kind: 'html_meta', content: '<meta name="a" content="b">')
      snippet!(name: 'good', content: 'stillRuns()')
      allow_any_instance_of(BetterTogether::PlatformSnippet).to receive(:meta_tags).and_raise('boom') # rubocop:disable RSpec/AnyInstance
      get page_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('stillRuns()')
    end

    it 'stops loading an external script once its origin leaves the allow-list' do # rubocop:disable RSpec/MultipleExpectations
      platform.update!(csp_script_src_text: 'https://cdn.example.com')
      snippet!(kind: 'script_src', content: nil, src: 'https://cdn.example.com/a.js')
      get page_path
      expect(response.body).to include('https://cdn.example.com/a.js')

      platform.update!(csp_script_src_text: '')
      get page_path
      expect(response.body).not_to include('https://cdn.example.com/a.js')
    end
  end

  describe 'administration' do
    let(:index_path) { better_together.platform_platform_snippets_path(platform, locale:) }
    let(:valid_params) do
      { platform_snippet: { name: 'Hello', location: 'head_end', kind: 'script_inline', content: 'hi()' } }
    end

    it 'refuses stewards and anonymous visitors' do # rubocop:disable RSpec/MultipleExpectations
      get index_path
      expect(response).not_to have_http_status(:ok)

      sign_in steward
      get index_path
      expect(response).not_to have_http_status(:ok)
      expect do
        post index_path, params: valid_params
      rescue ActionController::RoutingError
        nil
      end.not_to change(BetterTogether::PlatformSnippet, :count)
    end

    it 'lets a code manager create a snippet, disabled by default, and audits it' do # rubocop:disable RSpec/MultipleExpectations
      sign_in code_manager
      expect { post index_path, params: valid_params }.to change(BetterTogether::PlatformSnippet, :count).by(1)

      snippet = BetterTogether::PlatformSnippet.last
      expect(snippet.enabled).to be(false)
      expect(snippet.updated_by).to eq(code_manager.person)
      expect(BetterTogether::PlatformSnippetAudit.where(snippet_id: snippet.id).pluck(:action)).to eq(['created'])
    end

    it 'does not widen the CSP unless the person also manages security' do # rubocop:disable RSpec/MultipleExpectations
      sign_in code_manager
      params = { platform_snippet: { name: 'Ext', location: 'head_end', kind: 'script_src',
                                     src: 'https://cdn.example.com/a.js', allow_csp_origin: '1' } }

      expect { post index_path, params: }.not_to change(BetterTogether::PlatformSnippet, :count)
      expect(platform.reload.csp_script_src).not_to include('https://cdn.example.com')
    end

    it 'adds the origin when the person manages code and security' do # rubocop:disable RSpec/MultipleExpectations
      both = code_manager
      platform.person_platform_memberships.find_or_create_by!(
        member: both.person, role: BetterTogether::Role.find_by!(identifier: 'platform_steward'), status: 'active'
      )
      sign_in both
      params = { platform_snippet: { name: 'Ext', location: 'head_end', kind: 'script_src',
                                     src: 'https://cdn.example.com/a.js', allow_csp_origin: '1' } }

      expect { post index_path, params: }.to change(BetterTogether::PlatformSnippet, :count).by(1)
      expect(platform.reload.csp_script_src).to include('https://cdn.example.com')
    end

    it 'reorders and deletes snippets' do # rubocop:disable RSpec/MultipleExpectations
      first = snippet!(name: 'one')
      second = snippet!(name: 'two')
      sign_in code_manager
      patch better_together.move_platform_platform_snippet_path(platform, second, direction: 'up', locale:)

      expect([first.reload.position, second.reload.position]).to eq([1, 0])
      expect { delete better_together.platform_platform_snippet_path(platform, first, locale:) }
        .to change(BetterTogether::PlatformSnippet, :count).by(-1)
    end

    it 'toggles the kill switch' do
      sign_in code_manager
      patch better_together.toggle_all_platform_platform_snippets_path(platform, enabled: false, locale:)

      expect(platform.reload.snippets_enabled?).to be(false)
    end
  end
end
