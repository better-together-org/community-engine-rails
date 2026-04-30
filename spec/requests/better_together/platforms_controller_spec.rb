# frozen_string_literal: true

require 'rails_helper'
require 'capybara/rspec'

RSpec.describe 'BetterTogether::PlatformsController', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let!(:content_publishing_agreement) do
    BetterTogether::Agreement.find_or_create_by!(identifier: BetterTogether::PublicVisibilityGate::AGREEMENT_IDENTIFIER)
  end
  let(:network_admin) do
    create(:better_together_user, :confirmed, :network_admin, email: 'platform-network-admin@example.test')
  end
  let(:approval_operator) do
    create(:better_together_user, :confirmed, email: 'platform-approver@example.test')
  end
  let(:safety_reviewer) do
    create(:better_together_user, :confirmed, email: 'platform-safety-reviewer@example.test')
  end

  def grant_platform_permission(user, permission_identifier)
    permission = BetterTogether::ResourcePermission.find_by(identifier: permission_identifier)
    return unless permission

    role = create(:better_together_role, :platform_role)
    BetterTogether::RoleResourcePermission.create!(role:, resource_permission: permission)
    host_platform = BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host)
    membership = host_platform.person_platform_memberships.find_or_initialize_by(member: user.person)
    membership.role = role
    membership.status = :active
    membership.save!
    user.person.touch
  end

  before do
    manager_person = BetterTogether::User.find_by(email: 'manager@example.test').person
    create(:better_together_agreement_participant,
           agreement: content_publishing_agreement,
           participant: manager_person,
           accepted_at: Time.current)
    grant_platform_permission(approval_operator, 'approve_network_connections')
    grant_platform_permission(safety_reviewer, 'manage_platform_safety')
  end

  describe 'GET /:locale/.../host/platforms' do
    it 'renders index' do
      get better_together.platforms_path(locale:)
      expect(response).to have_http_status(:ok)
    end

    it 'renders platform rows in the host table view' do
      platform = create(:better_together_platform, identifier: "row-platform-#{SecureRandom.hex(4)}")

      get better_together.platforms_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(<tr id="#{ActionView::RecordIdentifier.dom_id(platform)}"))
    end

    it 'renders show for host platform' do
      host_platform = BetterTogether::Platform.find_by(host: true)
      get better_together.platform_path(locale:, id: host_platform.slug)
      expect(response).to have_http_status(:ok)
    end

    it 'shows federation access from the platform profile to network admins' do
      host_platform = BetterTogether::Platform.find_by(host: true)
      remote_platform = create(:better_together_platform,
                               name: 'Neighbourhood Commons',
                               identifier: "neighbourhood-commons-#{SecureRandom.hex(4)}")
      unrelated_platform = create(:better_together_platform,
                                  name: 'Unrelated Platform',
                                  identifier: "unrelated-platform-#{SecureRandom.hex(4)}")
      create(:better_together_platform_connection,
             :active,
             source_platform: host_platform,
             target_platform: remote_platform)
      create(:better_together_platform_connection,
             :active,
             source_platform: unrelated_platform,
             target_platform: create(:better_together_platform))

      sign_in network_admin

      get better_together.platform_path(locale:, id: host_platform.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Federation')
      expect(response.body).to include('Federation Connections')
      expect(response.body).to include('Open Connections')
      expect(response.body).to include('Neighbourhood Commons')
      expect(response.body).not_to include('Unrelated Platform')
    end

    it 'shows federation access to approval-only operators without creation controls' do
      host_platform = BetterTogether::Platform.find_by(host: true)
      create(:better_together_platform_connection, source_platform: host_platform)

      sign_in approval_operator

      get better_together.platform_path(locale:, id: host_platform.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Federation')
      expect(response.body).to include('Open Connections')
      expect(response.body).not_to include('New Connection')
    end

    it 'keeps federation controls hidden for platform managers without connection permissions' do
      host_platform = BetterTogether::Platform.find_by(host: true)

      get better_together.platform_path(locale:, id: host_platform.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('Federation Connections')
      expect(response.body).not_to include('Open Connections')
    end

    it 'shows safety review access from the host platform profile to safety reviewers' do
      host_platform = BetterTogether::Platform.find_by(host: true)
      report = create(:report,
                      reporter: create(:better_together_person),
                      reportable: create(:better_together_person),
                      harm_level: 'urgent',
                      retaliation_risk: true)
      safety_case = BetterTogether::Safety::Case.create!(
        report:,
        category: report.category,
        harm_level: report.harm_level,
        requested_outcome: report.requested_outcome,
        retaliation_risk: report.retaliation_risk,
        consent_to_contact: report.consent_to_contact,
        consent_to_restorative_process: report.consent_to_restorative_process
      )
      BetterTogether::Safety::Note.create!(
        safety_case:,
        author: safety_reviewer.person,
        visibility: 'participant_visible',
        body: 'Participant follow-up added for review.'
      )

      sign_in safety_reviewer

      get better_together.platform_path(locale:, id: host_platform.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Safety')
      expect(response.body).to include('Safety Review')
      expect(response.body).to include('Open Review Queue')
      expect(response.body).to include('Review Submitted Reports')
      expect(response.body).to include('Retaliation Risk')
      expect(response.body).to include('Participant Updates')
    end

    it 'shows platform operations entry points to platform managers' do
      host_platform = BetterTogether::Platform.find_by(host: true)

      get better_together.platform_path(locale:, id: host_platform.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t('platforms.show.operations.title'))
      expect(response.body).to include(I18n.t('platforms.show.operations.storage_configurations'))
      expect(response.body).to include(better_together.platform_storage_configurations_path(host_platform, locale: locale))
    end

    it 'keeps safety review controls hidden for platform managers without safety permissions' do
      host_platform = BetterTogether::Platform.find_by(host: true)

      get better_together.platform_path(locale:, id: host_platform.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('Safety Review')
      expect(response.body).not_to include('Open Review Queue')
    end

    it 'shows values-aligned CSP preset options instead of corporate defaults' do
      host_platform = BetterTogether::Platform.find_by(host: true)
      host_platform.update!(
        settings: host_platform.settings.merge(
          'csp_frame_ancestors' => [],
          'csp_frame_src' => [],
          'csp_img_src' => [],
          'csp_script_src' => [],
          'csp_connect_src' => []
        )
      )

      get better_together.edit_platform_path(locale:, id: host_platform.slug)

      page = Capybara.string(response.body)
      frame_src_select = page.find("select[name='platform[csp_frame_src_text][]']", visible: false)
      frame_ancestor_select = page.find("select[name='platform[csp_frame_ancestors_text][]']", visible: false)
      img_src_select = page.find("select[name='platform[csp_img_src_text][]']", visible: false)
      script_src_select = page.find("select[name='platform[csp_script_src_text][]']", visible: false)
      connect_src_select = page.find("select[name='platform[csp_connect_src_text][]']", visible: false)

      expect(response).to have_http_status(:ok)
      expect(frame_src_select).to have_css("option[value='https://forms.btsdev.ca']", visible: false)
      expect(frame_ancestor_select).to have_css("option[value='https://bebettertogether.ca']", visible: false)
      expect(img_src_select).to have_css("option[value='https://communityengine.app']", visible: false)
      expect(img_src_select).to have_css("option[value='https://*.tile.openstreetmap.org']", visible: false)
      expect(script_src_select).not_to have_css('option', visible: false)
      expect(connect_src_select).not_to have_css('option', visible: false)
      expect(frame_src_select).not_to have_css("option[value='https://www.youtube.com']", visible: false)
      expect(frame_src_select).not_to have_css("option[value='https://player.vimeo.com']", visible: false)
      expect(img_src_select).not_to have_css("option[value='https://images.ctfassets.net']", visible: false)
    end

    it 'renders the platform contributor display setting on edit' do
      host_platform = BetterTogether::Platform.find_by(host: true)

      get better_together.edit_platform_path(locale:, id: host_platform.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('platform[contributors_display_visibility]')
    end
  end

  describe 'GET /:locale/.../host/platforms/:id/available_people' do
    let(:host_platform) { BetterTogether::Platform.find_by(host: true) }

    it 'filters confirmed people by the search term' do
      matching_user = create(:better_together_user, :confirmed)
      matching_user.person.update!(name: 'Platform Matching Person')

      other_user = create(:better_together_user, :confirmed)
      other_user.person.update!(name: 'Different Person')

      get better_together.available_people_platform_path(host_platform, locale:, format: :json),
          params: { search: 'Matching' }

      expect(response).to have_http_status(:ok)

      results = JSON.parse(response.body)
      labels = results.pluck('text')

      expect(labels.any? { |text| text.include?('Platform Matching Person') }).to be(true)
      expect(labels.none? { |text| text.include?('Different Person') }).to be(true)
    end
  end

  describe 'PATCH /:locale/.../host/platforms/:id' do
    let(:host_platform) { BetterTogether::Platform.find_by(host: true) }

    # rubocop:todo RSpec/MultipleExpectations
    it 'updates settings and redirects' do # rubocop:todo RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      patch better_together.platform_path(locale:, id: host_platform.slug), params: {
        platform: { host_url: host_platform.host_url, time_zone: host_platform.time_zone, requires_invitation: true }
      }
      expect(response).to have_http_status(:see_other)
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end

    it 'persists CSP origin selections from multi-select inputs' do # rubocop:disable RSpec/MultipleExpectations
      patch better_together.platform_path(locale:, id: host_platform.slug), params: {
        platform: {
          host_url: host_platform.host_url,
          time_zone: host_platform.time_zone,
          csp_frame_ancestors_text: ['bebettertogether.ca'],
          csp_frame_src_text: ['forms.btsdev.ca', 'https://www.youtube.com'],
          csp_img_src_text: ['images.example.com'],
          csp_script_src_text: ['scripts.example.com'],
          csp_connect_src_text: ['collector.example.com']
        }
      }

      expect(response).to have_http_status(:see_other)
      expect(host_platform.reload.csp_frame_ancestors).to eq(['https://bebettertogether.ca'])
      expect(host_platform.csp_frame_src).to eq(['https://forms.btsdev.ca', 'https://www.youtube.com'])
      expect(host_platform.csp_img_src).to eq(['https://images.example.com'])
      expect(host_platform.csp_script_src).to eq(['https://scripts.example.com'])
      expect(host_platform.csp_connect_src).to eq(['https://collector.example.com'])
    end

    it 'persists the platform contributor display setting' do
      patch better_together.platform_path(locale:, id: host_platform.slug), params: {
        platform: {
          host_url: host_platform.host_url,
          time_zone: host_platform.time_zone,
          contributors_display_visibility: 'off'
        }
      }

      expect(host_platform.reload.contributors_display_visibility).to eq('off')
    end

    it 'renders edit when update params are invalid', :aggregate_failures do
      original_host_url = host_platform.host_url

      patch better_together.platform_path(locale:, id: host_platform.slug), params: {
        platform: {
          host_url: '',
          time_zone: host_platform.time_zone
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(host_platform.reload.host_url).to eq(original_host_url)
    end

    it 'applies platform-specific CSP origins to response headers' do # rubocop:disable RSpec/MultipleExpectations
      host_platform.update!(
        settings: host_platform.settings.merge(
          'csp_frame_ancestors' => ['https://bebettertogether.ca'],
          'csp_frame_src' => ['https://forms.btsdev.ca'],
          'csp_img_src' => ['https://images.example.com'],
          'csp_script_src' => ['https://scripts.example.com'],
          'csp_connect_src' => ['https://collector.example.com']
        )
      )

      get better_together.platforms_path(locale:)

      csp = response.headers['Content-Security-Policy']

      expect(csp).to include('frame-ancestors https://bebettertogether.ca')
      expect(csp).to include("frame-src 'self' https://forms.btsdev.ca")
      expect(csp).to include("img-src 'self' data: blob: https://*.tile.openstreetmap.org https://images.example.com")
      expected_script_src = [
        "script-src 'self' blob:",
        'https://scripts.example.com'
      ].join(' ')

      expect(csp).to include(expected_script_src)
      expect(csp).to include("connect-src 'self' wss: https://collector.example.com")
    end

    context 'when updating CSS block' do
      context 'when platform has no existing CSS block' do # rubocop:todo RSpec/NestedGroups
        before do
          # Ensure platform starts without a CSS block
          host_platform.blocks.where(type: 'BetterTogether::Content::Css').destroy_all
          host_platform.reload
        end

        it 'creates a new CSS block with content' do # rubocop:todo RSpec/MultipleExpectations
          css_identifier = "platform-custom-css-#{SecureRandom.hex(4)}"
          css_content = '.my-custom-class { color: blue; }'

          expect do
            patch better_together.platform_path(locale:, id: host_platform.slug), params: {
              platform: {
                host_url: host_platform.host_url,
                time_zone: host_platform.time_zone,
                css_block_attributes: {
                  type: 'BetterTogether::Content::Css',
                  identifier: css_identifier,
                  "content_#{locale}": css_content
                }
              }
            }
          end.to change { host_platform.reload.css_block.present? }.from(false).to(true)

          expect(response).to have_http_status(:see_other)

          css_block = host_platform.reload.css_block
          expect(css_block).to be_present
          expect(css_block.content).to eq(css_content)
          expect(css_block.identifier).to eq(css_identifier)
          expect(css_block.protected).to be(true)
        end

        it 'creates CSS block with complex real-world CSS' do # rubocop:todo RSpec/MultipleExpectations
          css_identifier = "platform-custom-css-#{SecureRandom.hex(4)}"
          complex_css = <<~CSS
            .notification form[action*="mark_as_read"] .btn[type="submit"] { z-index: 1200; }
            .card.journey-stage > .card-body { max-height: 50vh; }
            @media only screen and (min-width: 768px) {
              .hero-heading { font-size: 3em; }
            }
          CSS

          patch better_together.platform_path(locale:, id: host_platform.slug), params: {
            platform: {
              host_url: host_platform.host_url,
              time_zone: host_platform.time_zone,
              css_block_attributes: {
                type: 'BetterTogether::Content::Css',
                identifier: css_identifier,
                "content_#{locale}": complex_css
              }
            }
          }

          expect(response).to have_http_status(:see_other)

          css_block = host_platform.reload.css_block
          expect(css_block.content).to eq(complex_css)
        end
      end

      context 'when platform has existing CSS block' do # rubocop:todo RSpec/NestedGroups
        let(:existing_css_block) do
          create(:better_together_content_css,
                 identifier: "existing-platform-css-#{SecureRandom.hex(4)}",
                 content_text: '.old-class { color: red; }',
                 protected: true)
        end

        before do
          # Associate existing CSS block with platform
          host_platform.platform_blocks.create!(block: existing_css_block)
          host_platform.reload
        end

        it 'updates existing CSS block content' do # rubocop:todo RSpec/MultipleExpectations
          new_css_content = '.updated-class { color: green; }'

          patch better_together.platform_path(locale:, id: host_platform.slug), params: {
            platform: {
              host_url: host_platform.host_url,
              time_zone: host_platform.time_zone,
              css_block_attributes: {
                id: existing_css_block.id,
                type: 'BetterTogether::Content::Css',
                identifier: existing_css_block.identifier,
                "content_#{locale}": new_css_content
              }
            }
          }

          expect(response).to have_http_status(:see_other)

          existing_css_block.reload
          expect(existing_css_block.content).to eq(new_css_content)
        end

        it 'preserves CSS block ID when updating' do # rubocop:todo RSpec/MultipleExpectations
          original_id = existing_css_block.id
          new_css_content = '.another-class { font-size: 14px; }'

          patch better_together.platform_path(locale:, id: host_platform.slug), params: {
            platform: {
              host_url: host_platform.host_url,
              time_zone: host_platform.time_zone,
              css_block_attributes: {
                id: existing_css_block.id,
                type: 'BetterTogether::Content::Css',
                identifier: existing_css_block.identifier,
                "content_#{locale}": new_css_content
              }
            }
          }

          expect(response).to have_http_status(:see_other)

          css_block = host_platform.reload.css_block
          expect(css_block.id).to eq(original_id)
          expect(css_block.content).to eq(new_css_content)
        end

        it 'handles CSS with special characters and quotes' do # rubocop:todo RSpec/MultipleExpectations
          css_with_quotes = <<~CSS
            .notification form[action*="mark_as_read"] .btn[type="submit"] {
              z-index: 1200;
              position: relative;
            }
            .trix-content a[href]:not([href*="example.com"])::after {
              content: "\\f35d";
              font-family: "Font Awesome 6 Free";
            }
          CSS

          patch better_together.platform_path(locale:, id: host_platform.slug), params: {
            platform: {
              host_url: host_platform.host_url,
              time_zone: host_platform.time_zone,
              css_block_attributes: {
                id: existing_css_block.id,
                type: 'BetterTogether::Content::Css',
                identifier: existing_css_block.identifier,
                "content_#{locale}": css_with_quotes
              }
            }
          }

          expect(response).to have_http_status(:see_other)

          existing_css_block.reload
          expect(existing_css_block.content).to eq(css_with_quotes)
          # Verify special characters are preserved
          expect(existing_css_block.content).to include('[action*="mark_as_read"]')
          expect(existing_css_block.content).to include('content: "\\f35d"')
        end

        it 'clears CSS content when empty string submitted' do # rubocop:todo RSpec/MultipleExpectations
          patch better_together.platform_path(locale:, id: host_platform.slug), params: {
            platform: {
              host_url: host_platform.host_url,
              time_zone: host_platform.time_zone,
              css_block_attributes: {
                id: existing_css_block.id,
                type: 'BetterTogether::Content::Css',
                identifier: existing_css_block.identifier,
                "content_#{locale}": ''
              }
            }
          }

          expect(response).to have_http_status(:see_other)

          existing_css_block.reload
          expect(existing_css_block.content).to be_blank
        end
      end

      context 'when CSS block update fails validation' do # rubocop:todo RSpec/NestedGroups
        let(:css_identifier) { "existing-platform-css-#{SecureRandom.hex(4)}" }
        let(:existing_css_block) do
          create(:better_together_content_css,
                 identifier: css_identifier,
                 content_text: '.old-class { color: red; }',
                 protected: true)
        end

        before do
          host_platform.platform_blocks.create!(block: existing_css_block)
          host_platform.reload

          # Stub validation to force failure
          allow_any_instance_of(BetterTogether::Platform).to receive(:update).and_return(false) # rubocop:todo RSpec/AnyInstance
        end

        it 'renders edit form with unprocessable_content status' do # rubocop:todo RSpec/MultipleExpectations
          patch better_together.platform_path(locale:, id: host_platform.slug), params: {
            platform: {
              host_url: host_platform.host_url,
              time_zone: host_platform.time_zone,
              css_block_attributes: {
                id: existing_css_block.id,
                type: 'BetterTogether::Content::Css',
                identifier: existing_css_block.identifier,
                "content_#{locale}": '.new-class { color: blue; }'
              }
            }
          }

          expect(response).to have_http_status(:unprocessable_content)
          expect(response).to render_template(:edit)
        end
      end
    end
  end
end
