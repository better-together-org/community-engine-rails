# frozen_string_literal: true

require 'rails_helper'
require 'capybara/rspec'

RSpec.describe 'BetterTogether::PlatformsController', :as_platform_manager do
  let(:locale) { I18n.default_locale }

  describe 'GET /:locale/.../host/platforms' do
    it 'renders index' do
      get better_together.platforms_path(locale:)
      expect(response).to have_http_status(:ok)
    end

    it 'renders show for host platform' do
      host_platform = BetterTogether::Platform.find_by(host: true)
      get better_together.platform_path(locale:, id: host_platform.slug)
      expect(response).to have_http_status(:ok)
    end

    it 'shows values-aligned CSP preset options instead of corporate defaults' do
      host_platform = BetterTogether::Platform.find_by(host: true)
      host_platform.update!(
        settings: host_platform.settings.merge(
          'csp_frame_ancestors' => [],
          'csp_frame_src' => [],
          'csp_img_src' => []
        )
      )

      get better_together.edit_platform_path(locale:, id: host_platform.slug)

      page = Capybara.string(response.body)
      frame_src_select = page.find("select[name='platform[csp_frame_src_text][]']", visible: false)
      frame_ancestor_select = page.find("select[name='platform[csp_frame_ancestors_text][]']", visible: false)
      img_src_select = page.find("select[name='platform[csp_img_src_text][]']", visible: false)

      expect(response).to have_http_status(:ok)
      expect(frame_src_select).to have_css("option[value='https://forms.btsdev.ca']", visible: false)
      expect(frame_ancestor_select).to have_css("option[value='https://bebettertogether.ca']", visible: false)
      expect(img_src_select).to have_css("option[value='https://communityengine.app']", visible: false)
      expect(frame_src_select).not_to have_css("option[value='https://www.youtube.com']", visible: false)
      expect(frame_src_select).not_to have_css("option[value='https://player.vimeo.com']", visible: false)
      expect(img_src_select).not_to have_css("option[value='https://images.ctfassets.net']", visible: false)
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
          csp_img_src_text: ['images.example.com']
        }
      }

      expect(response).to have_http_status(:see_other)
      expect(host_platform.reload.csp_frame_ancestors).to eq(['https://bebettertogether.ca'])
      expect(host_platform.csp_frame_src).to eq(['https://forms.btsdev.ca', 'https://www.youtube.com'])
      expect(host_platform.csp_img_src).to eq(['https://images.example.com'])
    end

    it 'applies platform-specific CSP origins to response headers' do # rubocop:disable RSpec/MultipleExpectations
      host_platform.update!(
        settings: host_platform.settings.merge(
          'csp_frame_ancestors' => ['https://bebettertogether.ca'],
          'csp_frame_src' => ['https://forms.btsdev.ca'],
          'csp_img_src' => ['https://images.example.com']
        )
      )

      get better_together.platforms_path(locale:)

      csp = response.headers['Content-Security-Policy']

      expect(csp).to include('frame-ancestors https://bebettertogether.ca')
      expect(csp).to include("frame-src 'self' https://forms.btsdev.ca")
      expect(csp).to include("img-src 'self' data: blob: https://*.tile.openstreetmap.org https://images.example.com")
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
