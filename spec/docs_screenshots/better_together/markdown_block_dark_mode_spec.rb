# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/markdown_block_dark_mode_spec.rb
#
# Documents markdown content blocks in light and dark mode, and asserts the text meets WCAG AA contrast.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for markdown blocks in dark mode', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:host_platform) do
    configure_host_platform.tap { |platform| platform.update!(privacy: 'public', requires_invitation: false) }
  end
  let(:page_record) do
    create(:better_together_page, title: 'Dark mode page', slug: 'dark-mode-page', identifier: 'dark-mode-page',
                                  platform: host_platform, protected: false, privacy: 'public', published_at: 1.day.ago)
  end
  let(:source) do
    <<~MD
      ## What this site is

      A public host for Community Engine, with a [link](https://example.test), `inline code` and a list.

      - First point
      - Second point

      > A quoted line in the secondary colour.
    MD
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    page_record.page_blocks.create!(block: create(:content_markdown, markdown_source: source), position: 0)
  end

  after { Current.platform = nil }

  def metadata(flow)
    { locale: I18n.default_locale, role: 'anonymous', feature_set: 'markdown_block_dark_mode', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def show_page(mode)
    visit better_together.render_page_path(path: page_record.slug, locale: I18n.default_locale)
    expect(page).to have_css('.markdown-content p', wait: 10)
    page.execute_script("document.documentElement.setAttribute('data-bs-theme', '#{mode}')")
    find('.markdown-content').scroll_to(:top)
    sleep 0.3
  end

  # WCAG relative luminance contrast ratio between the paragraph colour and the page background.
  def contrast_ratio
    page.evaluate_script(<<~JS)
      (function () {
        const parse = (c) => c.match(/[\\d.]+/g).slice(0, 3).map(Number);
        const lum = (rgb) => { const [r, g, b] = rgb.map((v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); }); return 0.2126 * r + 0.7152 * g + 0.0722 * b; };
        const fg = parse(getComputedStyle(document.querySelector('.markdown-content p')).color);
        const bg = parse(getComputedStyle(document.body).backgroundColor);
        const [hi, lo] = [lum(fg), lum(bg)].sort((a, b) => b - a);
        return (hi + 0.05) / (lo + 0.05);
      })()
    JS
  end

  %w[light dark].each do |mode|
    it "captures the markdown block in #{mode} mode with readable text", :aggregate_failures do
      ratios = []
      result = BetterTogether::CapybaraScreenshotEngine.capture(
        "markdown_block_#{mode}_mode", device: :both, metadata: metadata("markdown_block_#{mode}_mode"),
                                       callouts: [{ selector: '.markdown-content', title: "Markdown block (#{mode})",
                                                    bullets: ['Text, headings and borders follow the colour mode.'] }]
      ) do
        show_page(mode)
        ratios << contrast_ratio
      end

      expect(ratios).not_to be_empty
      expect(ratios).to all(be >= 4.5)
      expect(result[:desktop]).to end_with("docs/screenshots/desktop/markdown_block_#{mode}_mode.png")
    end
  end
end
