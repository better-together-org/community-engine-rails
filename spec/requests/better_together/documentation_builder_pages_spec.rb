# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DocumentationBuilder pages', :as_platform_manager do
  let(:tmp_docs_root) { Pathname.new(Dir.mktmpdir('docs-request')) }
  let(:diagram_file_path) { tmp_docs_root.join('diagrams/source/request_flow.mmd') }
  let(:page_path) { "/#{I18n.default_locale}/docs/diagrammed" }

  before do
    FileUtils.mkdir_p(diagram_file_path.dirname)
    File.write(diagram_file_path, "graph TD\n  A --> B\n")

    File.write(
      tmp_docs_root.join('diagrammed.md'),
      <<~MARKDOWN
        # Diagrammed

        Intro text.

        <!-- mermaid-diagram: caption="Inline Flow" theme="forest" -->
        ```mermaid
        flowchart LR
          A --> B
        ```

        More text.

        <!-- mermaid-file: #{diagram_file_path}, caption="File Flow", theme="dark" -->

        Conclusion.
      MARKDOWN
    )

    allow(BetterTogether::DocumentationBuilder).to receive_messages(
      documentation_root: tmp_docs_root,
      documentation_url_prefix: '/docs'
    )

    BetterTogether::DocumentationBuilder.build
  end

  after do
    FileUtils.remove_entry(tmp_docs_root)
  end

  it 'renders markdown and mermaid blocks for built pages' do
    get page_path

    expect(response).to have_http_status(:ok)
    expect_html_contents('Intro text.', 'More text.', 'Conclusion.')
    expect(response.body.scan('mermaid-diagram-block').size).to eq(2)
    expect(response.body).to include('flowchart LR')
    expect(response.body).to include('graph TD')
    expect(response.body).to include('Inline Flow')
    expect(response.body).to include('File Flow')
  end
end
