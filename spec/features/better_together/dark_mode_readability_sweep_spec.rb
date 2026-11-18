# frozen_string_literal: true

require 'rails_helper'

# Pages that used a fixed light background (bg-light, bg-white, btn-light, hard-coded greys) must keep their text at
# WCAG AA (4.5:1 text, 3:1 icons) when the colour mode is dark, and must still pass in light mode.
RSpec.describe 'Dark mode readability of previously light-only pages', :js, :no_auth, :skip_host_setup, retry: 0 do
  include BetterTogether::CapybaraFeatureHelpers
  include BetterTogether::ColourContrastHelpers

  let(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let(:host_platform) do
    configure_host_platform.tap { |platform| platform.update!(privacy: 'public', requires_invitation: false) }
  end
  let(:locale) { I18n.default_locale }

  before do
    Current.platform = host_platform
    manager
    capybara_login_as_platform_manager
  end

  after { Current.platform = nil }

  def settle(mode)
    page.execute_script(<<~JS)
      const style = document.createElement('style');
      style.textContent = '*, *::before, *::after { transition: none !important; animation: none !important; }';
      document.head.appendChild(style);
      document.documentElement.setAttribute('data-bs-theme', '#{mode}');
    JS
  end

  # Only the surfaces this sweep is about are measured; the rest of each page belongs to other sweeps.
  def problems_for(mode, scopes)
    settle(mode)
    scopes.flat_map do |scope|
      page.evaluate_script("(function(){ #{contrast_script(scope)} })()").map { |line| "[#{mode}] #{line}" }
    end
  end

  # The block picker draws a glyph over a tile; both are text colours, so compare them to each other.
  def picker_problems(mode)
    settle(mode)
    page.evaluate_script(<<~JS).map { |line| "[#{mode}] #{line}" }
      (function(){ #{colour_helpers_js}
        return Array.from(document.querySelectorAll('#available-block-types .fa-stack')).filter((stack) => {
          const tile = stack.querySelector('.fa-stack-2x'); const glyph = stack.querySelector('.fa-stack-1x');
          return ratio(rgba(getComputedStyle(glyph).color), rgba(getComputedStyle(tile).color)) < 3;
        }).map((stack) => 'block picker icon ' + stack.querySelector('.fa-stack-1x').className + ' below 3:1');
      })()
    JS
  end

  def expect_readable_in_both_modes(*scopes, extra: nil)
    problems = %w[light dark].flat_map do |mode|
      found = problems_for(mode, scopes)
      found += send(extra, mode) if extra
      found.uniq
    end
    expect(problems).to be_empty, "#{problems.size} problems:\n#{problems.join("\n")}"
  end

  it 'keeps a seed page readable' do
    seed = create(:better_together_seed)
    visit better_together.seed_path(seed.id, locale:)
    expect(page).to have_css('pre.bg-body-tertiary', wait: 10)
    expect_readable_in_both_modes('pre.bg-body-tertiary')
  end

  it 'keeps a personal seed page readable' do
    seed = create(:better_together_seed, :personal_export, person: manager.person)
    visit better_together.person_seed_path(seed, locale:)
    expect(page).to have_css('pre.bg-body-tertiary', wait: 10)
    expect_readable_in_both_modes('pre.bg-body-tertiary')
  end

  it 'keeps the event form with its host card readable' do
    event = create(:better_together_event, :upcoming)
    BetterTogether::EventHost.create!(event:, host: create(:better_together_community))
    visit better_together.edit_event_path(event, locale:)
    expect(page).to have_css('#event-hosts-tab', wait: 10)
    page.execute_script("document.querySelector('#event-hosts-tab').click()")
    expect(page).to have_css('#event-hosts.show .card.bg-body-tertiary', wait: 10)
    expect_readable_in_both_modes('#event-hosts .card.bg-body-tertiary h6', '#event-hosts .card.bg-body-tertiary .text-muted')
  end

  it 'keeps a conversation with messages readable' do
    other = create(:better_together_person)
    conversation = create(:better_together_conversation, creator: manager.person)
    conversation.participants << other unless conversation.participants.include?(other)
    conversation.messages.create!(sender: other, content: 'A message from someone else')
    conversation.messages.create!(sender: manager.person, content: 'A message from me')
    visit better_together.conversation_path(conversation, locale:)
    expect(page).to have_css('.message-bubble', wait: 10)
    expect_readable_in_both_modes('.message-bubble')
  end

  it 'keeps a page with a blocked iframe embed readable' do
    record = create(:better_together_page, platform: host_platform, protected: false, privacy: 'public',
                                           published_at: 1.day.ago)
    record.page_blocks.create!(block: create(:content_iframe_block, iframe_url_en: 'https://blocked.example.test/form'),
                               position: 0)
    visit better_together.render_page_path(path: record.slug, locale:)
    expect(page).to have_css('.iframe-block__notice', wait: 10)
    expect_readable_in_both_modes('.iframe-block__notice')
  end

  it 'keeps the page editor block picker readable' do
    record = create(:better_together_page, platform: host_platform, protected: false, privacy: 'public',
                                           published_at: 1.day.ago)
    visit better_together.edit_page_path(record, locale:)
    expect(page).to have_css('#available-block-types', visible: :all, wait: 10)
    page.execute_script("document.querySelector('#available-block-types').classList.add('show')")
    expect(page).to have_css('#available-block-types .fa-stack', minimum: 1)
    expect_readable_in_both_modes('#available-block-types h5', extra: :picker_problems)
  end

  it 'keeps the platform form readable' do
    visit better_together.edit_platform_path(host_platform, locale:)
    expect(page).to have_css('#platform-features-tab', wait: 10)
    page.execute_script("document.querySelector('#platform-features-tab').click()")
    expect(page).to have_css('#platform-features.show', wait: 5)
    expect_readable_in_both_modes('#platform-features .card.bg-body-tertiary', '#platform-features .border.rounded-3')
  end
end
