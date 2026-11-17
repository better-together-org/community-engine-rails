# frozen_string_literal: true

# Capture command (run from repo root):
#   RUN_DOCS_SCREENSHOTS=1 bin/dc-run bundle exec prspec \
#     spec/docs_screenshots/better_together/trix_editor_dark_mode_spec.rb
#
# Documents the Trix toolbar and colour dialog in light and dark mode. Toolbar icons are dark SVGs, so dark mode
# must invert them, and the toolbar text must stay readable on the dark surface.

require 'rails_helper'

RSpec.describe 'Documentation screenshots for the Trix editor in dark mode', # rubocop:disable RSpec/SpecFilePathSuffix
               :docs_screenshot,
               :js,
               :skip_host_setup,
               retry: 0,
               type: :feature do
  include BetterTogether::CapybaraFeatureHelpers

  let(:manager) { find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_manager) }
  let(:host_platform) do
    configure_host_platform.tap { |platform| platform.update!(privacy: 'public', requires_invitation: false) }
  end

  before do
    skip 'Set RUN_DOCS_SCREENSHOTS=1 to generate documentation screenshots.' unless ENV['RUN_DOCS_SCREENSHOTS'] == '1'

    Current.platform = host_platform
    manager
  end

  after { Current.platform = nil }

  def metadata(flow)
    { locale: I18n.default_locale, role: 'platform_manager', feature_set: 'trix_editor_dark_mode', flow:,
      source_spec: self.class.metadata[:file_path] }
  end

  def show_editor(mode)
    capybara_login_as_platform_manager
    visit better_together.new_post_path(locale: I18n.default_locale)
    expect(page).to have_css('trix-toolbar .trix-button--icon-bold', wait: 10)
    page.execute_script("document.documentElement.setAttribute('data-bs-theme', '#{mode}')")
    scroll_to(find('trix-toolbar', match: :first), align: :center)
    sleep 0.3
  end

  def computed(selector, property, pseudo: nil)
    page.evaluate_script(
      "getComputedStyle(document.querySelector(#{selector.to_json}), #{pseudo.to_json})[#{property.to_json}]"
    )
  end

  %w[light dark].each do |mode|
    it "captures the Trix toolbar in #{mode} mode", :aggregate_failures do
      checks = {}
      BetterTogether::CapybaraScreenshotEngine.capture(
        "trix_toolbar_#{mode}_mode", device: :both, metadata: metadata("trix_toolbar_#{mode}_mode"),
                                     callouts: [{ selector: 'trix-toolbar', title: "Trix toolbar (#{mode})",
                                                  bullets: ['Icons and borders follow the colour mode.'] }]
      ) do
        show_editor(mode)
        checks[:filter] = computed('trix-toolbar .trix-button--icon-bold', 'filter', pseudo: '::before')
        checks[:dialog_bg] = computed('trix-toolbar .trix-dialog', 'backgroundColor')
      end

      expect(checks[:filter]).to(mode == 'dark' ? include('invert') : eq('none'))
    end

    it "captures the unannotated Trix toolbar in #{mode} mode" do
      BetterTogether::CapybaraScreenshotEngine.capture(
        "trix_toolbar_#{mode}_mode_plain", device: :both, metadata: metadata("trix_toolbar_#{mode}_mode_plain")
      ) do
        show_editor(mode)
        expect(page).to have_css('trix-toolbar .trix-button--icon-bold')
      end
    end

    it "captures the active bold button in #{mode} mode", :aggregate_failures do
      checks = {}
      BetterTogether::CapybaraScreenshotEngine.capture(
        "trix_active_button_#{mode}_mode", device: :both, metadata: metadata("trix_active_button_#{mode}_mode"),
                                           callouts: [{ selector: 'trix-toolbar .trix-button--icon-bold',
                                                        title: "Active button (#{mode})",
                                                        bullets: ['Active state uses the theme subtle primary.'] }]
      ) do
        show_editor(mode)
        find('trix-editor', match: :first).click
        find('trix-toolbar .trix-button--icon-bold', match: :first).click
        expect(page).to have_css('trix-toolbar .trix-button--icon-bold.trix-active')
        checks[:active_bg] = computed('trix-toolbar .trix-button--icon-bold.trix-active', 'backgroundColor')
        checks[:page_bg] = computed('body', 'backgroundColor')
      end

      expect(checks[:active_bg]).not_to eq(checks[:page_bg])
    end

    it "captures the unannotated active bold button in #{mode} mode" do
      BetterTogether::CapybaraScreenshotEngine.capture(
        "trix_active_button_#{mode}_mode_plain", device: :both,
                                                 metadata: metadata("trix_active_button_#{mode}_mode_plain")
      ) do
        show_editor(mode)
        find('trix-editor', match: :first).click
        find('trix-toolbar .trix-button--icon-bold', match: :first).click
        expect(page).to have_css('trix-toolbar .trix-button--icon-bold.trix-active')
      end
    end

    { 'link' => ['link', '.trix-dialog[data-trix-dialog="href"]'],
      'heading' => ['x-heading', '.trix-dialog--heading'],
      'color' => ['x-color', '.trix-dialog--color'] }.each do |name, (action, dialog)|
      it "captures the #{name} dialog in #{mode} mode", :aggregate_failures do
        checks = {}
        [true, false].each do |annotated|
          options = { device: :both, metadata: metadata("trix_#{name}_dialog_#{mode}_mode") }
          if annotated
            options[:callouts] = [{ selector: 'trix-toolbar', title: "#{name.capitalize} dialog (#{mode})",
                                    bullets: ['Dialog surface, inputs and buttons follow the colour mode.'] }]
          end
          BetterTogether::CapybaraScreenshotEngine.capture(
            "trix_#{name}_dialog_#{mode}_mode#{'_plain' unless annotated}", **options
          ) do
            show_editor(mode)
            find('trix-editor', match: :first).click
            find(%(trix-toolbar [data-trix-action="#{action}"]), match: :first).click
            expect(page).to have_css("#{dialog}[data-trix-active]", wait: 5)
            checks[:bg] = computed("#{dialog}[data-trix-active]", 'backgroundColor')
            checks[:color] = computed("#{dialog}[data-trix-active]", 'color')
          end
        end

        expect(checks[:bg]).to(mode == 'dark' ? match(/\A(rgb\(3[0-9]|rgb\(2[0-9]|rgb\(1[0-9]|rgb\([0-9],)/) : eq('rgb(255, 255, 255)'))
        expect(checks[:color]).not_to eq(checks[:bg])
      end
    end
  end
end
