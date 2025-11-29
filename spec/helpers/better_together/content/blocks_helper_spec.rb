# frozen_string_literal: true

require 'rails_helper'

# Specs in this file have access to a helper object that includes
# the ContentBlocksHelper. For example:
#
# describe ContentBlocksHelper do
#   describe "string concat" do
#     it "concats two strings with spaces" do
#       expect(helper.concat_strings("this","that")).to eq("this that")
#     end
#   end
# end
module BetterTogether # rubocop:todo Metrics/ModuleLength
  RSpec.describe Content::BlocksHelper do
    describe '#sanitize_block_css' do
      context 'with safe CSS' do
        it 'returns the CSS unchanged' do
          css = '.my-class { color: red; }'
          expect(helper.sanitize_block_css(css)).to eq(css)
        end

        it 'preserves attribute selectors with quotes' do
          css = '.notification form[action*="mark_as_read"] .btn[type="submit"] { z-index: 1200; }'
          expect(helper.sanitize_block_css(css)).to eq(css)
        end

        it 'preserves child selectors' do
          css = '.card.journey-stage > .card-body { max-height: 50vh; }'
          expect(helper.sanitize_block_css(css)).to eq(css)
        end

        it 'preserves pseudo-selectors with quotes' do
          css = '.trix-content a[href]:not([href*="example.com"])::after { content: "\f35d"; }'
          expect(helper.sanitize_block_css(css)).to eq(css)
        end

        it 'preserves media queries' do
          css = '@media only screen and (min-width: 768px) { .hero-heading { font-size: 3em; } }'
          expect(helper.sanitize_block_css(css)).to eq(css)
        end

        it 'preserves CSS custom properties' do
          css = '.navbar { --bs-navbar-toggler-padding-x: 0.25rem; }'
          expect(helper.sanitize_block_css(css)).to eq(css)
        end

        it 'preserves important declarations' do
          css = '.element { color: #404de0 !important; }'
          expect(helper.sanitize_block_css(css)).to eq(css)
        end

        it 'preserves multiple selectors with various characters' do
          css = '.content_rich_text a, trix-editor a, .trix-content a { text-decoration: none; }'
          expect(helper.sanitize_block_css(css)).to eq(css)
        end
      end

      context 'with dangerous CSS patterns' do
        it 'removes expression() calls' do
          css = 'width: expression(alert("XSS"));'
          sanitized = helper.sanitize_block_css(css)
          expect(sanitized).not_to include('expression(')
          expect(sanitized).to eq('width: alert("XSS"));')
        end

        it 'removes expression() with different casing' do
          css = 'width: ExPrEsSiOn(alert("XSS"));'
          sanitized = helper.sanitize_block_css(css)
          expect(sanitized).not_to match(/expression\s*\(/i)
        end

        it 'removes javascript: URLs in url()' do
          css = 'background: url(javascript:alert("XSS"));'
          sanitized = helper.sanitize_block_css(css)
          expect(sanitized).not_to include('javascript:')
          # NOTE: The regex replaces the entire url(...) content but preserves closing paren
          expect(sanitized).to eq('background: url(""));')
        end

        it 'preserves safe url() calls' do
          css = 'background: url("/images/bg.png");'
          expect(helper.sanitize_block_css(css)).to eq(css)
        end

        it 'removes multiple dangerous patterns' do
          css = 'width: expression(alert(1)); background: url(javascript:void(0));'
          sanitized = helper.sanitize_block_css(css)
          expect(sanitized).not_to include('expression(')
          expect(sanitized).not_to include('javascript:')
        end
      end

      context 'with edge cases' do
        it 'returns empty string for nil input' do
          expect(helper.sanitize_block_css(nil)).to eq('')
        end

        it 'returns empty string for blank input' do
          expect(helper.sanitize_block_css('')).to eq('')
          # NOTE: sanitize_block_css treats whitespace-only as blank
          expect(helper.sanitize_block_css('   ')).to eq('')
        end

        it 'handles very long CSS strings' do
          long_css = '.class { color: red; }' * 1000
          expect(helper.sanitize_block_css(long_css)).to eq(long_css)
        end
      end
    end

    describe '#sanitize_block_html' do
      it 'allows safe HTML tags' do
        html = '<p>Hello <strong>world</strong></p>'
        expect(helper.sanitize_block_html(html)).to eq(html)
      end

      it 'removes script tags' do
        html = '<p>Hello</p><script>alert("XSS")</script>'
        sanitized = helper.sanitize_block_html(html)
        expect(sanitized).not_to include('<script>')
        expect(sanitized).to include('<p>Hello</p>')
      end

      it 'allows whitelisted attributes' do
        html = '<a href="http://example.com" class="link" target="_blank">Link</a>'
        expect(helper.sanitize_block_html(html)).to eq(html)
      end
    end

    describe '#acceptable_image_file_types' do
      it 'returns valid image content types' do
        types = helper.acceptable_image_file_types
        expect(types).to be_an(Array)
        expect(types).to include('image/jpeg', 'image/png', 'image/gif')
      end
    end

    describe '#temp_id_for' do
      let(:persisted_model) { double('Model', persisted?: true, id: 123) } # rubocop:todo RSpec/VerifiedDoubles
      let(:new_model) { double('Model', persisted?: false) } # rubocop:todo RSpec/VerifiedDoubles

      it 'returns model id for persisted models' do
        expect(helper.temp_id_for(persisted_model)).to eq(123)
      end

      it 'returns temp_id for new models' do
        temp_id = 'temp-uuid-123'
        expect(helper.temp_id_for(new_model, temp_id: temp_id)).to eq(temp_id)
      end

      it 'generates a UUID for new models by default' do
        result = helper.temp_id_for(new_model)
        expect(result).to be_a(String)
        expect(result).to match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)
      end
    end
  end
end
