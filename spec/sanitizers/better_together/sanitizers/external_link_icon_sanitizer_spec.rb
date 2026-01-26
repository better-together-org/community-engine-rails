# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  # rubocop:disable Metrics/ModuleLength
  module Sanitizers
    RSpec.describe ExternalLinkIconSanitizer do
      let(:sanitizer) { described_class.new }
      let(:host) { 'example.com' }

      before do
        allow(Rails.application.routes.default_url_options).to receive(:[]).with(:host).and_return(host)
      end

      describe '#sanitize' do
        context 'with internal links' do
          it 'does not add icon to same-host links' do
            html = '<a href="http://example.com/page">Internal Link</a>'
            result = sanitizer.sanitize(html)

            expect(result).not_to include('fa-external-link-alt')
            expect(result).not_to include('external-link')
          end

          it 'does not modify relative links' do
            html = '<a href="/about">About</a>'
            result = sanitizer.sanitize(html)

            expect(result).not_to include('fa-external-link-alt')
          end

          it 'handles links without protocol' do
            html = '<a href="page">Page</a>'
            result = sanitizer.sanitize(html)

            expect(result).not_to include('fa-external-link-alt')
          end

          it 'handles hash links' do
            html = '<a href="#section">Section</a>'
            result = sanitizer.sanitize(html)

            expect(result).not_to include('fa-external-link-alt')
          end
        end

        context 'with external links' do
          it 'adds Font Awesome icon to external links' do
            html = '<a href="https://external.com/page">External Link</a>'
            result = sanitizer.sanitize(html)

            expect(result).to include('fa-external-link-alt')
            expect(result).to include('fas')
          end

          it 'adds external-link class' do
            html = '<a href="https://external.com/page">External Link</a>'
            result = sanitizer.sanitize(html)

            expect(result).to include('class="external-link"')
          end

          it 'appends icon after link text' do
            html = '<a href="https://external.com/page">External Link</a>'
            result = sanitizer.sanitize(html)

            # Icon should be after the text
            expect(result).to match(/External Link.*<i/m)
          end

          it 'preserves existing link classes' do
            html = '<a href="https://external.com/page" class="btn btn-primary">External Link</a>'
            result = sanitizer.sanitize(html)

            expect(result).to include('btn btn-primary external-link')
          end

          it 'handles multiple external links' do
            html = '<a href="https://site1.com">Site 1</a> <a href="https://site2.com">Site 2</a>'
            result = sanitizer.sanitize(html)

            # Both links should have icons
            expect(result.scan('fa-external-link-alt').count).to eq(2)
            # Class appears on both link and icon (2 links × 2 occurrences = 4)
            expect(result.scan('external-link').count).to eq(4)
          end
        end

        context 'with mixed internal and external links' do
          let(:mixed_html) do
            <<~HTML
              <div>
                <a href="/internal">Internal</a>
                <a href="https://external.com">External</a>
                <a href="http://example.com/local">Local</a>
              </div>
            HTML
          end

          it 'only adds icons to external links' do
            result = sanitizer.sanitize(mixed_html)

            # Only one external link should have icon
            expect(result.scan('fa-external-link-alt').count).to eq(1)
          end

          it 'preserves internal links unchanged' do
            result = sanitizer.sanitize(mixed_html)

            expect(result).to include('<a href="/internal">Internal</a>')
          end
        end

        context 'with malformed URLs' do
          it 'handles invalid URLs gracefully' do
            html = '<a href="ht!tp://invalid">Invalid</a>'
            result = sanitizer.sanitize(html)

            # Should not crash, URL parsing fails gracefully
            expect(result).to be_a(String)
          end

          it 'handles URLs without host' do
            html = '<a href="javascript:alert(1)">JS Link</a>'
            result = sanitizer.sanitize(html)

            # javascript: URLs have no host, should not crash
            expect(result).to be_a(String)
          end

          it 'handles empty href' do
            html = '<a href="">Empty</a>'
            result = sanitizer.sanitize(html)

            expect(result).to be_a(String)
          end
        end

        context 'with different protocols' do
          it 'handles HTTPS links' do
            html = '<a href="https://secure.com">Secure</a>'
            result = sanitizer.sanitize(html)

            expect(result).to include('fa-external-link-alt')
          end

          it 'handles HTTP links' do
            html = '<a href="http://insecure.com">Insecure</a>'
            result = sanitizer.sanitize(html)

            expect(result).to include('fa-external-link-alt')
          end

          it 'handles FTP links' do
            html = '<a href="ftp://files.com">FTP</a>'
            result = sanitizer.sanitize(html)

            expect(result).to include('fa-external-link-alt')
          end

          it 'handles mailto links' do
            html = '<a href="mailto:test@example.com">Email</a>'
            result = sanitizer.sanitize(html)

            # mailto has no host, should not add external icon
            expect(result).not_to include('fa-external-link-alt')
          end

          it 'handles tel links' do
            html = '<a href="tel:+1234567890">Phone</a>'
            result = sanitizer.sanitize(html)

            # tel has no host, should not add external icon
            expect(result).not_to include('fa-external-link-alt')
          end
        end

        context 'with complex HTML structures' do
          it 'handles nested elements in links' do
            html = '<a href="https://external.com"><span class="text">Link</span></a>'
            result = sanitizer.sanitize(html)

            expect(result).to include('fa-external-link-alt')
          end

          it 'handles links with images' do
            html = '<a href="https://external.com"><img src="/image.png" alt="Image"></a>'
            result = sanitizer.sanitize(html)

            expect(result).to include('fa-external-link-alt')
          end

          it 'handles multiple links in complex structure' do
            html = <<~HTML
              <nav>
                <ul>
                  <li><a href="/home">Home</a></li>
                  <li><a href="https://external.com">External</a></li>
                </ul>
              </nav>
            HTML
            result = sanitizer.sanitize(html)

            expect(result.scan('fa-external-link-alt').count).to eq(1)
          end
        end

        context 'with sanitizer options' do
          it 'passes options to parent sanitize method' do
            html = '<a href="https://external.com">Link</a><script>alert(1)</script>'
            result = sanitizer.sanitize(html)

            # Should sanitize the script tag while preserving the link
            expect(result).not_to include('<script>')
            expect(result).to include('fa-external-link-alt')
          end

          it 'preserves safe HTML tags' do
            html = '<div><a href="https://external.com"><strong>Bold Link</strong></a></div>'
            result = sanitizer.sanitize(html)

            expect(result).to include('<strong>')
            expect(result).to include('fa-external-link-alt')
          end
        end

        context 'when default_url_options host is localhost' do
          before do
            allow(Rails.application.routes.default_url_options).to receive(:[]).with(:host).and_return('localhost')
          end

          it 'treats localhost links as internal' do
            html = '<a href="http://localhost:3000/page">Localhost</a>'
            result = sanitizer.sanitize(html)

            expect(result).not_to include('fa-external-link-alt')
          end

          it 'treats other hosts as external' do
            html = '<a href="http://example.com/page">Example</a>'
            result = sanitizer.sanitize(html)

            expect(result).to include('fa-external-link-alt')
          end
        end

        context 'when default_url_options host is nil' do
          before do
            allow(Rails.application.routes.default_url_options).to receive(:[]).with(:host).and_return(nil)
          end

          it 'defaults to localhost' do
            html = '<a href="http://localhost/page">Localhost</a>'
            result = sanitizer.sanitize(html)

            expect(result).not_to include('fa-external-link-alt')
          end

          it 'treats other hosts as external' do
            html = '<a href="http://example.com/page">Example</a>'
            result = sanitizer.sanitize(html)

            expect(result).to include('fa-external-link-alt')
          end
        end

        context 'icon rendering' do
          it 'creates proper icon HTML structure' do
            html = '<a href="https://external.com">Link</a>'
            result = sanitizer.sanitize(html)

            # Should have <i> tag with proper classes
            expect(result).to match(%r{<i[^>]+class="fas fa-external-link-alt"[^>]*></i>})
          end

          it 'adds icon with space before it' do
            html = '<a href="https://external.com">Link</a>'
            result = sanitizer.sanitize(html)

            # Should have space before icon
            expect(result).to match(/Link\s+<i/)
          end
        end
      end

      describe 'inheritance' do
        it 'inherits from Rails::HTML5::SafeListSanitizer' do
          expect(described_class.superclass).to eq(Rails::HTML5::SafeListSanitizer)
        end

        it 'can be used as a sanitizer' do
          expect(sanitizer).to respond_to(:sanitize)
        end
      end
    end
  end
  # rubocop:enable Metrics/ModuleLength
end
