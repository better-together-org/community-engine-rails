# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HtmlAssertionHelpers, type: :request do
  include described_class

  # Mock response object with controllable HTML content
  let(:mock_response) { double('response') }

  before do
    allow(self).to receive(:response).and_return(mock_response)
  end

  describe 'HTML entity escaping scenarios' do
    context 'with apostrophe escaping' do
      let(:html_content) do
        <<~HTML
          <html>
            <body>
              <h1>Member Directory</h1>
              <div class="member-card">
                <span class="name">Patrick O&#39;Brien</span>
                <span class="role">Community O&#39;Malley</span>
              </div>
              <div class="member-card">
                <span class="name">Mary&#39;s Profile</span>
              </div>
            </body>
          </html>
        HTML
      end

      before do
        allow(mock_response).to receive(:body).and_return(html_content)
      end

      describe '#parsed_response' do
        it 'returns a Nokogiri document' do
          expect(parsed_response).to be_a(Nokogiri::HTML::Document)
        end

        it 'caches the parsed response' do
          first_call = parsed_response
          second_call = parsed_response
          expect(first_call.object_id).to eq(second_call.object_id)
        end

        it 'parses HTML structure correctly' do
          expect(parsed_response.css('.member-card').count).to eq(2)
          expect(parsed_response.at_css('h1').text).to eq('Member Directory')
        end
      end

      describe '#response_text' do
        it 'extracts plain text from HTML' do
          expect(response_text).to be_a(String)
          expect(response_text).to include('Member Directory')
        end

        it 'unescapes HTML entities automatically' do
          # The critical test: HTML entities should be decoded
          expect(response_text).to include("Patrick O'Brien")
          expect(response_text).to include("Community O'Malley")
          expect(response_text).to include("Mary's Profile")
        end

        it 'does not include HTML tags in text' do
          expect(response_text).not_to include('<div')
          expect(response_text).not_to include('<span')
        end
      end

      describe '#expect_html_content' do
        it 'finds content with apostrophes' do
          expect { expect_html_content("Patrick O'Brien") }.not_to raise_error
          expect { expect_html_content("Community O'Malley") }.not_to raise_error
          expect { expect_html_content("Mary's Profile") }.not_to raise_error
        end

        it 'finds partial content' do
          expect { expect_html_content("O'Brien") }.not_to raise_error
          expect { expect_html_content("Mary's") }.not_to raise_error
        end

        it 'raises error when content not present' do
          expect { expect_html_content('Not Present') }
            .to raise_error(RSpec::Expectations::ExpectationNotMetError)
        end

        it 'is case-sensitive' do
          expect { expect_html_content("patrick o'brien") }
            .to raise_error(RSpec::Expectations::ExpectationNotMetError)
        end
      end

      describe '#expect_no_html_content' do
        it 'passes when content not present' do
          expect { expect_no_html_content('Not Present') }.not_to raise_error
          expect { expect_no_html_content('John Doe') }.not_to raise_error
        end

        it 'raises error when content is present' do
          expect { expect_no_html_content("Patrick O'Brien") }
            .to raise_error(RSpec::Expectations::ExpectationNotMetError)
        end

        it 'works with apostrophes in negative assertions' do
          expect { expect_no_html_content("Jane O'Reilly") }.not_to raise_error
        end
      end

      describe '#expect_html_contents' do
        it 'finds multiple texts all present' do
          expect do
            expect_html_contents(
              "Patrick O'Brien",
              "Community O'Malley",
              "Mary's Profile"
            )
          end.not_to raise_error
        end

        it 'raises error if any text missing' do
          expect do
            expect_html_contents(
              "Patrick O'Brien",
              'Not Present',
              "Mary's Profile"
            )
          end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /Not Present/)
        end

        it 'works with single text' do
          expect { expect_html_contents("Patrick O'Brien") }.not_to raise_error
        end

        it 'works with empty array' do
          expect { expect_html_contents }.not_to raise_error
        end
      end

      describe '#expect_no_html_contents' do
        it 'passes when all texts absent' do
          expect do
            expect_no_html_contents(
              'Not Present',
              'Also Missing',
              'Not Here Either'
            )
          end.not_to raise_error
        end

        it 'raises error if any text found' do
          expect do
            expect_no_html_contents(
              'Not Present',
              "Patrick O'Brien"
            )
          end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /Patrick O'Brien/)
        end
      end

      describe '#expect_element_content' do
        it 'finds element by selector with escaped content' do
          expect { expect_element_content('.name', "Patrick O'Brien") }.not_to raise_error
          expect { expect_element_content('.role', "Community O'Malley") }.not_to raise_error
        end

        it 'raises error when element not found' do
          expect { expect_element_content('.not-exists', 'Any Text') }
            .to raise_error(RSpec::Expectations::ExpectationNotMetError, /not found/)
        end

        it 'raises error when element exists but text does not match' do
          expect { expect_element_content('.name', 'Wrong Name') }
            .to raise_error(RSpec::Expectations::ExpectationNotMetError, /Expected element.*to include/)
        end

        it 'uses first matching element when multiple exist' do
          # First .name element is "Patrick O'Brien"
          expect { expect_element_content('.name', 'Patrick') }.not_to raise_error
        end
      end

      describe '#expect_element_with_text' do
        it 'finds element containing specific text' do
          expect { expect_element_with_text('.member-card', "Patrick O'Brien") }.not_to raise_error
          expect { expect_element_with_text('.member-card', "Mary's Profile") }.not_to raise_error
        end

        it 'searches across multiple matching elements' do
          # Should find second .member-card containing Mary's Profile
          expect { expect_element_with_text('.member-card', "Mary's") }.not_to raise_error
        end

        it 'raises error when no elements match selector' do
          expect { expect_element_with_text('.not-exists', 'Text') }
            .to raise_error(RSpec::Expectations::ExpectationNotMetError, /No elements found/)
        end

        it 'raises error when elements exist but none contain text' do
          expect { expect_element_with_text('.member-card', 'Not Present') }
            .to raise_error(RSpec::Expectations::ExpectationNotMetError, /none found/)
        end
      end

      describe '#expect_element_without_text' do
        it 'passes when element does not contain text' do
          expect { expect_element_without_text('.name', 'Wrong Name') }.not_to raise_error
        end

        it 'passes when element does not exist' do
          expect { expect_element_without_text('.not-exists', 'Any Text') }.not_to raise_error
        end

        it 'raises error when element contains text' do
          expect { expect_element_without_text('.name', "Patrick O'Brien") }
            .to raise_error(RSpec::Expectations::ExpectationNotMetError)
        end
      end

      describe '#expect_element_count' do
        it 'verifies correct count' do
          expect { expect_element_count('.member-card', 2) }.not_to raise_error
          expect { expect_element_count('.name', 2) }.not_to raise_error
          expect { expect_element_count('h1', 1) }.not_to raise_error
        end

        it 'raises error when count does not match' do
          expect { expect_element_count('.member-card', 5) }
            .to raise_error(RSpec::Expectations::ExpectationNotMetError, /Expected 5.*found 2/)
        end

        it 'works with zero count' do
          expect { expect_element_count('.not-exists', 0) }.not_to raise_error
        end
      end

      describe '#element_texts' do
        it 'returns array of text contents' do
          names = element_texts('.name')
          expect(names).to be_an(Array)
          expect(names.size).to eq(2)
        end

        it 'unescapes HTML entities in returned texts' do
          names = element_texts('.name')
          expect(names).to include("Patrick O'Brien")
          expect(names).to include("Mary's Profile")
        end

        it 'returns empty array when no elements match' do
          expect(element_texts('.not-exists')).to eq([])
        end

        it 'can be used with standard RSpec matchers' do
          names = element_texts('.name')
          expect(names).to include("Patrick O'Brien")
          expect(names).not_to include('Not Present')
        end
      end
    end

    context 'with multiple escaping types' do
      let(:complex_html) do
        <<~HTML
          <html>
            <body>
              <div class="quote">He said &quot;Hello&quot;</div>
              <div class="ampersand">Widgets &amp; Gadgets</div>
              <div class="less-than">Price &lt; $100</div>
              <div class="greater-than">Value &gt; expectations</div>
              <div class="mixed">O&#39;Brien &amp; Co. &quot;Best&quot;</div>
            </body>
          </html>
        HTML
      end

      before do
        allow(mock_response).to receive(:body).and_return(complex_html)
      end

      it 'handles double quotes' do
        expect_html_content('He said "Hello"')
      end

      it 'handles ampersands' do
        expect_html_content('Widgets & Gadgets')
      end

      it 'handles less-than signs' do
        expect_html_content('Price < $100')
      end

      it 'handles greater-than signs' do
        expect_html_content('Value > expectations')
      end

      it 'handles mixed entity types' do
        expect_html_content('O\'Brien & Co. "Best"')
      end
    end

    context 'with Unicode characters' do
      let(:unicode_html) do
        <<~HTML
          <html>
            <body>
              <div class="unicode">Café résumé naïve</div>
              <div class="emoji">Welcome 👋 to our community!</div>
            </body>
          </html>
        HTML
      end

      before do
        allow(mock_response).to receive(:body).and_return(unicode_html)
      end

      it 'handles accented characters' do
        expect_html_content('Café résumé naïve')
      end

      it 'handles emoji' do
        expect_html_content('Welcome 👋 to our community!')
      end
    end

    context 'with nested HTML structure' do
      let(:nested_html) do
        <<~HTML
          <html>
            <body>
              <div class="outer">
                <div class="inner">
                  <span class="deep">Patrick O&#39;Brien</span>
                </div>
              </div>
            </body>
          </html>
        HTML
      end

      before do
        allow(mock_response).to receive(:body).and_return(nested_html)
      end

      it 'finds content in deeply nested elements' do
        expect_html_content("Patrick O'Brien")
      end

      it 'can target specific nested elements' do
        expect_element_content('.deep', "Patrick O'Brien")
        expect_element_content('.inner', "Patrick O'Brien")
        expect_element_content('.outer', "Patrick O'Brien")
      end
    end
  end

  describe 'edge cases' do
    context 'with empty HTML' do
      before do
        allow(mock_response).to receive(:body).and_return('')
      end

      it 'handles empty response gracefully' do
        expect(response_text).to eq('')
        expect { expect_no_html_content('Any Text') }.not_to raise_error
      end
    end

    context 'with whitespace-only HTML' do
      before do
        allow(mock_response).to receive(:body).and_return('   ')
      end

      it 'treats whitespace as empty' do
        expect(response_text.strip).to eq('')
      end
    end

    context 'with malformed HTML' do
      let(:malformed_html) do
        <<~HTML
          <html>
            <body>
              <div class="unclosed">Patrick O&#39;Brien
              <span>Some text</span>
            </body>
        HTML
      end

      before do
        allow(mock_response).to receive(:body).and_return(malformed_html)
      end

      it 'parses malformed HTML gracefully' do
        expect { expect_html_content("Patrick O'Brien") }.not_to raise_error
        expect { expect_html_content('Some text') }.not_to raise_error
      end
    end
  end

  describe 'caching behavior' do
    let(:html_content) { '<html><body>Test</body></html>' }

    before do
      allow(mock_response).to receive(:body).and_return(html_content)
    end

    it 'caches parsed_response within test' do
      first = parsed_response
      second = parsed_response
      expect(first.object_id).to eq(second.object_id)
    end

    it 'response_text uses cached parsed_response' do
      # First call should parse and cache
      first_text = response_text

      # Subsequent calls should use cached version
      second_text = response_text

      # Both should return same result
      expect(first_text).to eq(second_text)

      # Verify only one Nokogiri parse occurred
      expect(mock_response).to have_received(:body).once
    end
  end

  describe 'real-world scenario: testing person names from factories' do
    let(:html_with_factory_data) do
      <<~HTML
        <html>
          <body>
            <h1>Community Members</h1>
            <table class="members-table">
              <tr>
                <td class="name">Sean O&#39;Connor</td>
                <td class="role">Community O&#39;Malley</td>
              </tr>
              <tr>
                <td class="name">Mary McDonald&#39;s</td>
                <td class="role">Platform Admin</td>
              </tr>
              <tr>
                <td class="name">D&#39;Angelo Russell</td>
                <td class="role">Content Moderator</td>
              </tr>
            </table>
          </body>
        </html>
      HTML
    end

    before do
      allow(mock_response).to receive(:body).and_return(html_with_factory_data)
    end

    it 'finds all member names with apostrophes' do
      expect_html_contents(
        "Sean O'Connor",
        "Mary McDonald's",
        "D'Angelo Russell"
      )
    end

    it 'finds role names with apostrophes' do
      expect_html_content("Community O'Malley")
    end

    it 'can verify member count' do
      expect_element_count('tr', 3)
    end

    it 'can get all member names' do
      names = element_texts('.name')
      expect(names).to contain_exactly(
        "Sean O'Connor",
        "Mary McDonald's",
        "D'Angelo Russell"
      )
    end

    it 'works with negative assertions for private members' do
      expect_no_html_content('Private User')
      expect_no_html_content("Hidden O'Reilly")
    end
  end
end
