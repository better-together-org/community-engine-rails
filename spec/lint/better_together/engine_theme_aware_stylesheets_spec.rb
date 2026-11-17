# frozen_string_literal: true

require 'rails_helper'

# Dark mode sets data-bs-theme="dark" on <html>, which only changes Bootstrap's CSS variables. A hard-coded hex
# colour in these rules stays light-theme and becomes unreadable (dark text on a dark page).
RSpec.describe BetterTogether::Engine, '.theme_aware_stylesheets', type: :lint do
  let(:root) { described_class.root.join('app/assets/stylesheets/better_together') }

  it 'uses Bootstrap theme variables, not hex colours, for markdown content', :aggregate_failures do
    lines = root.join('content_blocks.scss').read.lines
    start = lines.index { |line| line.start_with?('.markdown-content') }
    markdown = lines[start..].join

    expect(markdown).not_to match(/#[0-9a-fA-F]{3,8}\b/)
    expect(markdown).to match(/color:\s*var\(--bs-body-color\)/)
  end

  it 'keeps the admin block card and sidebar headings theme aware', :aggregate_failures do
    expect(root.join('content_blocks.scss').read[/\.page-block-fields \{.*?\n\}/m]).not_to match(/#[0-9a-fA-F]{3,8}\b/)
    expect(root.join('sidebar_nav.scss').read).not_to match(/#[0-9a-fA-F]{3,8}\b/)
  end
end
