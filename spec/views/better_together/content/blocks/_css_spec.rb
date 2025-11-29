# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Content # rubocop:todo Metrics/ModuleLength
    RSpec.describe 'better_together/content/blocks/_css.html.erb' do
      let(:platform) { create(:better_together_platform) }
      let(:creator) { create(:better_together_person) }

      before do
        configure_host_platform
      end

      context 'when CSS block has content' do
        let(:css_block) do
          create(:better_together_content_css,
                 creator: creator,
                 content_text: '.my-class { color: red; }')
        end

        it 'renders a style tag' do
          render partial: 'better_together/content/blocks/css', locals: { css: css_block }

          expect(rendered).to have_css('style[type="text/css"]', visible: :all)
        end

        it 'includes the CSS content' do
          render partial: 'better_together/content/blocks/css', locals: { css: css_block }

          expect(rendered).to include('.my-class { color: red; }')
        end

        it 'includes the block DOM ID' do
          render partial: 'better_together/content/blocks/css', locals: { css: css_block }

          expect(rendered).to have_css("style##{dom_id(css_block)}", visible: :all)
        end

        context 'with attribute selectors containing quotes' do
          let(:css_with_quotes) do
            create(:better_together_content_css,
                   creator: creator,
                   content_text: '.notification form[action*="mark_as_read"] .btn[type="submit"] { z-index: 1200; }')
          end

          it 'renders quotes correctly without HTML escaping' do
            render partial: 'better_together/content/blocks/css', locals: { css: css_with_quotes }

            # Check that quotes are NOT escaped to &quot;
            expect(rendered).to include('[action*="mark_as_read"]')
            expect(rendered).to include('[type="submit"]')
            expect(rendered).not_to include('&quot;')
          end
        end

        context 'with child selectors' do
          let(:css_with_child_selector) do
            create(:better_together_content_css,
                   creator: creator,
                   content_text: '.card.journey-stage > .card-body { max-height: 50vh; }')
          end

          it 'renders child selectors correctly without HTML escaping' do
            render partial: 'better_together/content/blocks/css', locals: { css: css_with_child_selector }

            # Check that > is NOT escaped to &gt;
            expect(rendered).to include('.card.journey-stage > .card-body')
            expect(rendered).not_to include('&gt;')
          end
        end

        context 'with pseudo-selectors and content property' do
          let(:css_with_pseudo) do
            create(:better_together_content_css,
                   creator: creator,
                   content_text: '.trix-content a[href]:not([href*="example.com"])::after { content: "\f35d"; }')
          end

          it 'renders pseudo-selectors and content values correctly' do
            render partial: 'better_together/content/blocks/css', locals: { css: css_with_pseudo }

            expect(rendered).to include('::after')
            expect(rendered).to include('content: "\f35d"')
            expect(rendered).to include('[href*="example.com"]')
            expect(rendered).not_to include('&quot;')
          end
        end

        context 'with media queries' do
          let(:css_with_media_query) do
            create(:better_together_content_css,
                   creator: creator,
                   content_text: '@media only screen and (min-width: 768px) { .hero-heading { font-size: 3em; } }')
          end

          it 'renders media queries correctly' do
            render partial: 'better_together/content/blocks/css', locals: { css: css_with_media_query }

            expect(rendered).to include('@media only screen and (min-width: 768px)')
            expect(rendered).to include('.hero-heading { font-size: 3em; }')
          end
        end

        context 'with CSS custom properties' do
          let(:css_with_custom_props) do
            create(:better_together_content_css,
                   creator: creator,
                   content_text: '.navbar { --bs-navbar-toggler-padding-x: 0.25rem; }')
          end

          it 'renders CSS custom properties correctly' do
            render partial: 'better_together/content/blocks/css', locals: { css: css_with_custom_props }

            expect(rendered).to include('--bs-navbar-toggler-padding-x: 0.25rem;')
          end
        end

        context 'with important declarations' do
          let(:css_with_important) do
            create(:better_together_content_css,
                   creator: creator,
                   content_text: '.icon-bg { color: #404de0 !important; }')
          end

          it 'renders important declarations correctly' do
            render partial: 'better_together/content/blocks/css', locals: { css: css_with_important }

            expect(rendered).to include('color: #404de0 !important;')
          end
        end

        context 'with complex real-world CSS' do
          let(:complex_css) do
            <<~CSS
              .leaflet-top, .leaflet-bottom { z-index: 999; }
              #content_hero_ea08d542-1eea-4d82-8a6b-eb3f1adc58b5 .hero-heading { margin: 0 auto; }
              @media only screen and (min-width: 768px) {
                #content_hero_ea08d542-1eea-4d82-8a6b-eb3f1adc58b5 .hero-heading { font-size: 3em; }
              }
              .notification form[action*="mark_as_read"] .btn[type="submit"] { z-index: 1200; position: relative; }
              .card.journey-stage > .card-body { max-height: 50vh; }
              .trix-content a[href]:not([href*="newcomernavigatornl.ca"]):not([href^="mailto:"]):not([href^="tel:"]):not([href$=".pdf"])::after {
                font-family: "Font Awesome 6 Free";
                content: "\\f35d";
                font-weight: 900;
              }
              body[data-viewable-id="97d554df-6f55-41a9-9a78-021a8965f49d"] .cover-image { object-position: center 20%; }
            CSS
          end

          let(:css_with_complex_rules) do
            create(:better_together_content_css,
                   creator: creator,
                   content_text: complex_css)
          end

          it 'renders all CSS patterns correctly without escaping' do
            render partial: 'better_together/content/blocks/css', locals: { css: css_with_complex_rules }

            # Verify no HTML escaping occurred
            expect(rendered).not_to include('&quot;')
            expect(rendered).not_to include('&gt;')
            expect(rendered).not_to include('&lt;')

            # Verify specific patterns are present
            expect(rendered).to include('.leaflet-top, .leaflet-bottom')
            expect(rendered).to include('[action*="mark_as_read"]')
            expect(rendered).to include('.card.journey-stage > .card-body')
            expect(rendered).to include('::after')
            expect(rendered).to include('[href*="newcomernavigatornl.ca"]')
            expect(rendered).to include('[data-viewable-id="97d554df-6f55-41a9-9a78-021a8965f49d"]')
          end
        end

        context 'with dangerous CSS patterns' do
          let(:css_with_expression) do
            create(:better_together_content_css,
                   creator: creator,
                   content_text: 'width: expression(alert("XSS")); color: red;')
          end

          let(:css_with_javascript_url) do
            create(:better_together_content_css,
                   creator: creator,
                   content_text: 'background: url(javascript:alert("XSS"));')
          end

          it 'sanitizes dangerous expression() calls' do
            render partial: 'better_together/content/blocks/css', locals: { css: css_with_expression }

            expect(rendered).not_to include('expression(')
            expect(rendered).to include('color: red;')
          end

          it 'sanitizes javascript: URLs' do
            render partial: 'better_together/content/blocks/css', locals: { css: css_with_javascript_url }

            expect(rendered).not_to include('javascript:')
            expect(rendered).to include('url("")')
          end
        end
      end

      context 'when CSS block has no content' do
        let(:empty_css_block) do
          create(:better_together_content_css,
                 creator: creator,
                 content_text: nil)
        end

        it 'does not render a style tag' do
          render partial: 'better_together/content/blocks/css', locals: { css: empty_css_block }

          expect(rendered).not_to have_css('style')
          expect(rendered.strip).to be_empty
        end
      end

      context 'when CSS block has blank content' do
        let(:blank_css_block) do
          create(:better_together_content_css,
                 creator: creator,
                 content_text: '   ')
        end

        it 'does not render a style tag' do
          render partial: 'better_together/content/blocks/css', locals: { css: blank_css_block }

          expect(rendered).not_to have_css('style')
          expect(rendered.strip).to be_empty
        end
      end
    end
  end
end
