# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Mermaid Diagrams', :js do
  include BetterTogether::CapybaraFeatureHelpers

  before do
    configure_host_platform
  end

  let!(:page_with_diagram) do
    create(:better_together_page,
           privacy: 'public',
           published_at: 1.day.ago)
  end

  context 'when viewing a page with mermaid diagrams' do
    scenario 'renders simple flowchart diagram' do
      markdown_text = <<~MARKDOWN
        # Documentation with Diagram

        Here is a simple flowchart:

        ```mermaid
        graph TD
          A[Start] --> B[Process]
          B --> C{Decision}
          C -->|Yes| D[End]
          C -->|No| B
        ```
      MARKDOWN

      markdown_block = create(:content_markdown, markdown_source: markdown_text)
      page_with_diagram.page_blocks.create!(block: markdown_block, position: 0)

      visit better_together.render_page_path(page_with_diagram.slug, locale: I18n.default_locale)

      # Wait for page to load and Stimulus controller to initialize
      expect(page).to have_css('.markdown-content[data-controller="better-together--mermaid"]')

      # Wait for Mermaid to render the diagram (may take a moment)
      within('.markdown-content') do
        expect(page).to have_css('pre.mermaid-diagram svg', wait: 5)
      end
    end

    scenario 'renders sequence diagram' do
      markdown_text = <<~MARKDOWN
        # Sequence Diagram Example

        ```mermaid
        sequenceDiagram
          participant User
          participant Server
          User->>Server: Request
          Server-->>User: Response
        ```
      MARKDOWN

      markdown_block = create(:content_markdown, markdown_source: markdown_text)
      page_with_diagram.page_blocks.create!(block: markdown_block, position: 0)

      visit better_together.render_page_path(page_with_diagram.slug, locale: I18n.default_locale)

      within('.markdown-content') do
        expect(page).to have_css('pre.mermaid-diagram svg', wait: 5)
      end
    end

    scenario 'renders multiple diagrams on the same page' do
      markdown_text = <<~MARKDOWN
        # Multiple Diagrams

        First diagram:

        ```mermaid
        graph LR
          A --> B
        ```

        Second diagram:

        ```mermaid
        graph TD
          C --> D
        ```
      MARKDOWN

      markdown_block = create(:content_markdown, markdown_source: markdown_text)
      page_with_diagram.page_blocks.create!(block: markdown_block, position: 0)

      visit better_together.render_page_path(page_with_diagram.slug, locale: I18n.default_locale)

      within('.markdown-content') do
        # Should render both diagrams
        expect(page).to have_css('pre.mermaid-diagram svg', count: 2, wait: 5)
      end
    end

    scenario 'handles invalid diagram syntax gracefully' do
      markdown_text = <<~MARKDOWN
        # Invalid Diagram

        ```mermaid
        This is not valid mermaid syntax
        ```
      MARKDOWN

      markdown_block = create(:content_markdown, markdown_source: markdown_text)
      page_with_diagram.page_blocks.create!(block: markdown_block, position: 0)

      visit better_together.render_page_path(page_with_diagram.slug, locale: I18n.default_locale)

      # Page should still load even with invalid syntax
      expect(page).to have_css('.markdown-content')

      # Error handling should display error message
      within('.markdown-content') do
        expect(page).to have_css('.mermaid-error, .alert-danger', wait: 5)
      end
    end

    scenario 'preserves diagrams through turbo navigation', skip: 'Requires multiple pages to test Turbo navigation' do
      # This would test that diagrams re-render correctly when navigating
      # between pages using Turbo Drive
    end
  end

  context 'when markdown renderer processes mermaid code blocks' do
    scenario 'preserves mermaid code blocks with proper class' do
      markdown_text = <<~MARKDOWN
        ```mermaid
        graph TD
          A-->B
        ```
      MARKDOWN

      markdown_block = create(:content_markdown, markdown_source: markdown_text)
      page_with_diagram.page_blocks.create!(block: markdown_block, position: 0)

      visit better_together.render_page_path(page_with_diagram.slug, locale: I18n.default_locale)

      # The markdown renderer should preserve the code block with .mermaid-diagram class
      expect(page).to have_css('pre.mermaid-diagram', wait: 2)
    end
  end
end
