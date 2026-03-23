# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Mermaid diagram rendering' do
  let(:page) do
    create(
      :better_together_page,
      title: 'Test Page',
      slug: 'test-page',
      privacy: 'public',
      published_at: 1.day.ago
    )
  end

  let(:page_path) { "/#{I18n.default_locale}/#{page.slug}" }

  let(:mermaid_diagram) do
    create(:better_together_content_mermaid_diagram,
           diagram_source: "graph TD\n  A[Start] --> B[End]",
           caption: 'Test Diagram',
           theme: 'default')
  end

  let!(:page_block) do
    create(:better_together_page_block, page: page, block: mermaid_diagram, position: 1)
  end

  describe 'rendering with JavaScript enabled' do
    it 'displays mermaid source code in pre tag', :as_user do
      get page_path

      expect(response).to have_http_status(:success)
      expect_html_content('graph TD')
      expect_html_content('A[Start] --> B[End]')
    end

    it 'includes mermaid controller', :as_user do
      get page_path

      expect(response.body).to include('data-controller="better-together--mermaid"')
    end

    it 'includes theme value', :as_user do
      get page_path

      expect(response.body).to include('data-better-together--mermaid-theme-value="default"')
    end

    it 'displays caption when present', :as_user do
      get page_path

      expect_html_content('Test Diagram')
    end
  end

  describe 'rendering without JavaScript (noscript)' do
    context 'when rendered_image is attached' do
      before do
        skip 'rendered_image attachment not implemented yet (Future enhancement)'
        png_data = +"\x89PNG\r\n\x1a\n"
        png_data.force_encoding('ASCII-8BIT')
        mermaid_diagram.rendered_image.attach(
          io: StringIO.new(png_data),
          filename: 'diagram.png',
          content_type: 'image/png'
        )
      end

      it 'includes noscript tag with image', :as_user do
        get page_path

        expect(response.body).to include('<noscript>')
        expect(response.body).to include('img')
      end

      it 'uses caption as alt text when available', :as_user do
        get page_path

        expect(response.body).to include('alt="Test Diagram"')
      end

      it 'uses default alt text when caption is blank', :as_user do
        mermaid_diagram.update!(caption: nil)
        get page_path

        expect(response.body).to include('alt="Mermaid diagram"')
      end
    end

    context 'when rendered_image is not attached' do
      it 'shows JavaScript required message', :as_user do
        skip 'Noscript fallback message not implemented yet (Future enhancement)'
        get page_path

        parsed = Nokogiri::HTML(response.body)
        noscript_content = parsed.css('noscript').text

        expect(noscript_content).to include('JavaScript is required')
      end
    end
  end

  describe 'rendering with different themes' do
    %w[default dark forest neutral].each do |theme|
      it "renders with #{theme} theme", :as_user do
        mermaid_diagram.update!(theme: theme)
        get page_path

        expect(response.body).to include("data-better-together--mermaid-theme-value=\"#{theme}\"")
      end
    end
  end

  describe 'rendering with auto_height' do
    it 'includes auto-height class when enabled', :as_user do
      mermaid_diagram.update!(auto_height: true)
      get page_path

      expect(response.body).to include('class="mermaid-diagram-wrapper auto-height"')
    end

    it 'excludes auto-height class when disabled', :as_user do
      mermaid_diagram.update!(auto_height: false)
      get page_path

      expect(response.body).to include('class="mermaid-diagram-wrapper "')
      expect(response.body).not_to include('auto-height')
    end
  end

  describe 'with missing content' do
    it 'shows warning message', :as_user do
      I18n.with_locale(:en) do
        mermaid_diagram.diagram_source = nil
        mermaid_diagram.diagram_file_path = nil
        mermaid_diagram.save(validate: false)
      end
      get page_path

      expect(response.body).to include('alert-warning')
      expect_html_content('No diagram content available')
    end
  end
end
