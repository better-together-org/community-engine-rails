# frozen_string_literal: true

require 'rails_helper'

# Integration test to verify HTML assertion helpers work in real request specs
RSpec.describe 'HtmlAssertionHelpers Integration' do
  let(:person) do
    create(:better_together_person,
           name: "Patrick O'Brien") # Name with apostrophe
  end

  let(:role) do
    create(:better_together_role,
           name: "Community O'Malley") # Role with apostrophe
  end

  before do
    # Create a simple controller action that renders person name
    allow_any_instance_of(ActionDispatch::Response).to receive(:body).and_return(
      <<~HTML
        <html>
          <body>
            <h1>Welcome</h1>
            <div class="person-name">#{ERB::Util.html_escape(person.name)}</div>
            <div class="role-name">#{ERB::Util.html_escape(role.name)}</div>
          </body>
        </html>
      HTML
    )
  end

  describe 'using helper methods' do
    it 'finds person name with apostrophe using expect_html_content' do
      get '/', params: { locale: I18n.default_locale }
      expect_html_content(person.name)
    end

    it 'finds role name with apostrophe using response_text' do
      get '/', params: { locale: I18n.default_locale }
      expect(response_text).to include(role.name)
    end

    it 'finds multiple names using expect_html_contents' do
      get '/', params: { locale: I18n.default_locale }
      expect_html_contents(person.name, role.name)
    end

    it 'finds element by selector with apostrophe content' do
      get '/', params: { locale: I18n.default_locale }
      expect_element_content('.person-name', person.name)
      expect_element_content('.role-name', role.name)
    end
  end

  describe 'comparison with old approach' do
    it 'demonstrates the problem with direct response.body.include?' do
      get '/', params: { locale: I18n.default_locale }

      # OLD APPROACH (FAILS): Direct string comparison doesn't handle HTML escaping
      # expect(response.body).to include(person.name)  # Would fail!

      # This would fail because response.body contains "Patrick O&#39;Brien"
      # but person.name is "Patrick O'Brien"
      expect(response.body).not_to include(person.name) # Proves the old approach fails

      # NEW APPROACH (WORKS): Parse HTML first
      expect_html_content(person.name) # Works!
    end

    it 'shows HTML escaping in response.body' do
      get '/', params: { locale: I18n.default_locale }

      # Verify HTML contains escaped version
      expect(response.body).to include('O&#39;Brien') # Escaped apostrophe

      # But our helper handles it transparently
      expect_html_content("O'Brien") # Unescaped apostrophe
    end
  end
end
