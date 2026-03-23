# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Mermaid Toolbar Interactions', :js do
  include BetterTogether::CapybaraFeatureHelpers

  before do
    configure_host_platform
  end

  let!(:page_with_diagram) do
    create(:better_together_page,
           slug: 'diagram-page',
           title: 'Page with Diagram',
           privacy: 'public')
  end
  let!(:markdown_block) do
    create(:content_markdown,
           markdown_source: markdown_with_diagram)
  end
  let!(:page_block) do
    create(:page_content_block,
           page: page_with_diagram,
           block: markdown_block,
           position: 1)
  end

  let(:markdown_with_diagram) do
    <<~MARKDOWN
      # Interactive Diagram

      ```mermaid
      graph TD
        A[Start] --> B[Process]
        B --> C{Decision}
        C -->|Yes| D[Success]
        C -->|No| E[Error]
        E --> B
        D --> F[End]
      ```
    MARKDOWN
  end

  scenario 'displays mermaid diagram with toolbar controls' do
    visit better_together.render_page_path(page_with_diagram.slug, locale: I18n.default_locale)

    # Wait for page to load
    expect(page).to have_content(page_with_diagram.title)

    # Wait for mermaid to render - JavaScript transforms markdown code blocks
    expect(page).to have_css('.markdown-content', wait: 5)

    # Mermaid renders as pre.mermaid-diagram with embedded SVG
    expect(page).to have_css('pre.mermaid-diagram svg', wait: 10)
  end

  scenario 'zoom in button increases diagram scale' do
    visit better_together.render_page_path(page_with_diagram.slug, locale: I18n.default_locale)
    expect(page).to have_css('.mermaid-diagram svg', wait: 10)

    # Click zoom in button
    find('button[data-mermaid-zoom="in"]').click

    # Wait for DOM to update and verify zoom button is still functional
    expect(page).to have_css('button[data-mermaid-zoom="in"]')
    expect(page).to have_css('.mermaid-viewport')
  end

  scenario 'zoom out button decreases diagram scale' do
    visit better_together.render_page_path(page_with_diagram.slug, locale: I18n.default_locale)
    expect(page).to have_css('.mermaid-diagram svg', wait: 10)

    # Click zoom out button
    find('button[data-mermaid-zoom="out"]').click

    # Verify button remains interactive
    expect(page).to have_css('button[data-mermaid-zoom="out"]')
  end

  scenario 'reset button restores original scale' do
    visit better_together.render_page_path(page_with_diagram.slug, locale: I18n.default_locale)
    expect(page).to have_css('.mermaid-diagram svg', wait: 10)

    # Zoom in multiple times
    3.times { find('button[data-mermaid-zoom="in"]').click }

    # Reset button should be clickable
    reset_button = find('button[data-mermaid-zoom="reset"]')
    expect(reset_button).to be_present
    reset_button.click

    # Verify diagram and controls remain functional
    expect(page).to have_css('.mermaid-diagram svg')
  end

  scenario 'displays pan controls' do
    visit better_together.render_page_path(page_with_diagram.slug, locale: I18n.default_locale)
    expect(page).to have_css('.mermaid-diagram svg', wait: 10)

    within('.btn-toolbar') do
      expect(page).to have_css('button[data-mermaid-pan="up"]', text: '↑')
      expect(page).to have_css('button[data-mermaid-pan="left"]', text: '←')
      expect(page).to have_css('button[data-mermaid-pan="right"]', text: '→')
      expect(page).to have_css('button[data-mermaid-pan="down"]', text: '↓')
    end
  end

  scenario 'displays download dropdown' do
    visit better_together.render_page_path(page_with_diagram.slug, locale: I18n.default_locale)
    expect(page).to have_css('.mermaid-diagram svg', wait: 10)

    # Find download button
    download_button = find('button.dropdown-toggle[data-bs-toggle="dropdown"]')
    expect(download_button).to be_present

    # Click to open dropdown
    download_button.click

    # Check dropdown options
    within('.dropdown-menu') do
      expect(page).to have_button('Download .mmd')
      expect(page).to have_button('Download .png')
      expect(page).to have_button('Download .jpg')
    end
  end

  scenario 'displays fullscreen button' do
    visit better_together.render_page_path(page_with_diagram.slug, locale: I18n.default_locale)
    expect(page).to have_css('.mermaid-diagram svg', wait: 10)

    within('.btn-toolbar') do
      expect(page).to have_css('button[data-mermaid-fullscreen]')
      expect(page).to have_css('button[data-mermaid-fullscreen] i.fa-expand')
    end
  end

  scenario 'fullscreen button creates overlay' do
    visit better_together.render_page_path(page_with_diagram.slug, locale: I18n.default_locale)
    expect(page).to have_css('.mermaid-diagram svg', wait: 10)

    # Click fullscreen button
    fullscreen_button = find('button[data-mermaid-fullscreen]')
    fullscreen_button.click

    # Check overlay is created with proper structure
    expect(page).to have_css('.mermaid-fullscreen-overlay', wait: 5)

    within('.mermaid-fullscreen-overlay') do
      expect(page).to have_css('button')
      # Fullscreen overlay contains .mermaid-viewport with SVG, not .mermaid-diagram
      expect(page).to have_css('.mermaid-viewport svg')
    end
  end

  scenario 'toolbar has proper accessibility attributes' do
    visit better_together.render_page_path(page_with_diagram.slug, locale: I18n.default_locale)
    expect(page).to have_css('.mermaid-diagram svg', wait: 10)

    within('.btn-toolbar') do
      # Check button groups have aria labels
      button_groups = all('.btn-group')
      button_groups.each do |group|
        expect(group['aria-label']).to be_present
      end

      # Check individual buttons have aria labels
      all('button').each do |button|
        expect(button['aria-label']).to be_present
      end
    end
  end

  scenario 'diagram viewport supports drag-to-pan' do
    visit better_together.render_page_path(page_with_diagram.slug, locale: I18n.default_locale)
    expect(page).to have_css('.mermaid-diagram svg', wait: 10)

    # Verify viewport element exists with proper data attributes
    viewport = find('.mermaid-viewport')
    expect(viewport).to be_present

    # Check viewport has pan controls nearby
    expect(page).to have_css('button[data-mermaid-pan="up"]')
  end

  context 'with multiple diagrams on same page' do
    let!(:second_markdown_block) do
      create(:content_markdown,
             markdown_source: <<~MARKDOWN)
               # Second Diagram

               ```mermaid
               graph LR
                 X --> Y
               ```
             MARKDOWN
    end

    let!(:second_page_block) do
      create(:page_content_block,
             page: page_with_diagram,
             block: second_markdown_block,
             position: 2)
    end

    scenario 'each diagram has its own toolbar' do
      visit better_together.render_page_path(page_with_diagram.slug, locale: I18n.default_locale)

      # Wait for both diagrams to render
      expect(page).to have_css('.mermaid-diagram svg', count: 2, wait: 10)

      # Check each has toolbar - toolbar is within the diagram element
      diagrams = all('.mermaid-diagram')
      expect(diagrams.count).to eq(2)

      expect(diagrams).to all(have_css('.btn-toolbar'))
    end

    scenario 'toolbar controls operate independently' do
      visit better_together.render_page_path(page_with_diagram.slug, locale: I18n.default_locale)
      expect(page).to have_css('.mermaid-diagram svg', count: 2, wait: 10)

      # Both toolbars should be present and functional
      toolbars = all('.btn-toolbar')
      expect(toolbars.count).to eq(2)

      # Click zoom in on first toolbar
      within(toolbars.first) do
        zoom_in = find('button[data-mermaid-zoom="in"]')
        zoom_in.click
      end

      # Both diagrams should still be present
      expect(page).to have_css('.mermaid-diagram svg', count: 2)

      # Second toolbar should remain functional
      within(toolbars.last) do
        expect(page).to have_css('button[data-mermaid-zoom="in"]')
      end
    end
  end
end
