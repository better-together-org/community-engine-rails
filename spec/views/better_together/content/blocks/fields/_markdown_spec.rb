# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/content/blocks/fields/_markdown.html.erb' do
  let(:scope) { 'page[page_blocks_attributes][0][block_attributes]' }
  let(:temp_id) { 'markdown-field-spec' }

  def render_fields(block)
    render partial: 'better_together/content/blocks/fields/markdown',
           locals: { block:, scope:, temp_id: }
  end

  describe 'dependent fields wiring' do
    context 'when editing inline markdown content' do
      let(:block) { build(:content_markdown, markdown_source: '## Hello world', markdown_file_path: nil) }

      it 'keeps inline inputs visible and file inputs hidden' do
        render_fields(block)

        inline_id = "#{temp_id}_markdown_source_inline"
        page = Capybara.string(rendered)

        expect(page).to have_css(".markdown-fields[data-controller*='better-together--dependent-fields']")
        expect(page).to have_css(".markdown-inline-field:not(.hidden-field)[data-dependent-fields-control='#{inline_id}']")
        expect(page).to have_css(".markdown-inline-field[data-show-if-control_#{inline_id}='inline']")
        expect(page).to have_css('.markdown-file-field.hidden-field')
      end
    end

    context 'when referencing a markdown file' do
      let(:block) { build(:content_markdown, markdown_source: nil, markdown_file_path: 'docs/example.md') }

      it 'keeps file inputs visible and inline inputs hidden' do
        render_fields(block)
        file_id = "#{temp_id}_markdown_source_file"
        page = Capybara.string(rendered)

        expect(page).to have_css(".markdown-file-field:not(.hidden-field)[data-dependent-fields-control='#{file_id}']")
        expect(page).to have_css(".markdown-file-field[data-show-if-control_#{file_id}='file']")
        expect(page).to have_css('.markdown-inline-field.hidden-field')
      end
    end
  end
end
