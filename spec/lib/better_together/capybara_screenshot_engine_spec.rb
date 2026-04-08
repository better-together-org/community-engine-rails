# frozen_string_literal: true

require 'rails_helper'
require 'tmpdir'
require 'vips'

module BetterTogether # :nodoc:
  RSpec.describe CapybaraScreenshotEngine do
    describe '.capture' do
      it 'captures selector-targeted callouts into screenshot metadata without mutating the page' do
        Dir.mktmpdir do |dir|
          stub_const("#{described_class}::SCREENSHOT_ROOT", Pathname.new(dir))

          fake_page = instance_double(Capybara::Session)
          allow(described_class).to receive(:register_drivers)
          allow(described_class).to receive(:driver_for).and_return(:selenium_chrome_headless_docs_desktop)
          allow(described_class).to receive(:hide_sticky_elements)
          allow(described_class).to receive(:restore_sticky_elements)
          allow(Capybara).to receive(:reset_sessions!)
          allow(Capybara).to receive(:page).and_return(fake_page)
          allow(Capybara).to receive(:using_driver).and_yield
          allow(fake_page).to receive_messages(
            current_url: 'http://example.test/en/conversations/new',
            title: 'Test Host Community',
            evaluate_script: [
              { 'selector' => 'select[name="conversation[participant_ids][]"]', 'x' => 120, 'y' => 180, 'width' => 280, 'height' => 100 }
            ]
          )
          allow(fake_page).to receive(:save_screenshot) do |path|
            Vips::Image.black(900, 1200).new_from_image([255, 255, 255]).write_to_file(path)
          end

          result = described_class.capture(
            'conversation_scope',
            device: :desktop,
            metadata: { flow: 'conversation_participant_scope' },
            callouts: [
              {
                selector: 'select[name="conversation[participant_ids][]"]',
                title: 'Scoped conversation discovery for platform managers',
                bullets: ['Available in picker: Platform Steward']
              }
            ]
          )

          expect(result[:desktop]).to end_with('conversation_scope.png')

          metadata = JSON.parse(File.read(File.join(dir, 'desktop', 'conversation_scope.json')))
          expect(metadata['flow']).to eq('conversation_participant_scope')
          expect(metadata['url']).to eq('/en/conversations/new')
          expect(metadata).not_to have_key('captured_at')
          expect(metadata['callouts'].size).to eq(1)
          expect(metadata['callouts'].first['selector']).to eq('select[name="conversation[participant_ids][]"]')
          expect(metadata['callouts'].first['placement']['side']).to be_in(%w[right left above below floating])
          expect(File.stat(File.join(dir, 'desktop', 'conversation_scope.png')).mode & 0o777).to eq(0o644)
          expect(File.stat(File.join(dir, 'desktop', 'conversation_scope.json')).mode & 0o777).to eq(0o644)
        end
      end

      it 'fails closed when a declared callout selector cannot be resolved' do
        Dir.mktmpdir do |dir|
          stub_const("#{described_class}::SCREENSHOT_ROOT", Pathname.new(dir))

          fake_page = instance_double(Capybara::Session)
          allow(described_class).to receive(:register_drivers)
          allow(described_class).to receive(:driver_for).and_return(:selenium_chrome_headless_docs_desktop)
          allow(described_class).to receive(:hide_sticky_elements)
          allow(described_class).to receive(:restore_sticky_elements)
          allow(Capybara).to receive(:reset_sessions!)
          allow(Capybara).to receive(:page).and_return(fake_page)
          allow(Capybara).to receive(:using_driver).and_yield
          allow(fake_page).to receive_messages(
            current_url: 'http://example.test/en/conversations/new',
            title: 'Test Host Community',
            evaluate_script: []
          )

          expect do
            described_class.capture(
              'missing_callout',
              device: :desktop,
              callouts: [
                {
                  selector: 'select[name="conversation[participant_ids][]"]',
                  title: 'Scoped conversation discovery for platform managers',
                  bullets: ['Available in picker: self']
                }
              ]
            )
          end.to raise_error(
            described_class::CalloutTargetResolutionError,
            /Could not resolve screenshot callout target/
          )
        end
      end
    end
  end
end
