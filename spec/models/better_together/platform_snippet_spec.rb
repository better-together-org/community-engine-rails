# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PlatformSnippet do
  let(:platform) { BetterTogether::Platform.find_by(host: true) }
  let(:snippet) { build(nil, platform:) }

  def build(_name, platform:, **attrs)
    described_class.new({ platform:, name: 'Test', location: 'head_end', kind: 'script_inline',
                          content: 'window.x = 1;' }.merge(attrs))
  end

  it 'starts disabled' do
    expect(described_class.new.enabled).to be(false)
  end

  it 'is valid with sensible attributes' do
    expect(snippet).to be_valid
  end

  it 'rejects markup that could break out of the script or style element' do # rubocop:disable RSpec/MultipleExpectations
    expect(build(nil, platform:, content: 'a</script><script>b')).not_to be_valid
    expect(build(nil, platform:, content: '<!-- x')).not_to be_valid
    expect(build(nil, platform:, kind: 'style_inline', content: 'a{}</style>')).not_to be_valid
  end

  it 'limits content size' do
    expect(build(nil, platform:, content: 'a' * 20_001)).not_to be_valid
  end

  describe 'html_meta' do
    it 'accepts meta tags in the head only' do # rubocop:disable RSpec/MultipleExpectations
      meta = build(nil, platform:, kind: 'html_meta', content: '<meta name="x" content="y">')

      expect(meta).to be_valid
      meta.location = 'body_end'
      expect(meta).not_to be_valid
    end

    it 'rejects content with no allowed tags and drops event handler attributes' do # rubocop:disable RSpec/MultipleExpectations
      expect(build(nil, platform:, kind: 'html_meta', content: '<script>x</script>')).not_to be_valid
      meta = build(nil, platform:, kind: 'html_meta', content: '<meta name="x" content="y" onclick="z">')

      expect(meta.meta_tags.first[:attributes].keys).to contain_exactly('name', 'content')
    end
  end

  describe 'script_src' do
    let(:src_snippet) { build(nil, platform:, kind: 'script_src', content: nil, src: 'https://cdn.example.com/a.js') }

    it 'is rejected until the origin is on the platform script allow-list' do # rubocop:disable RSpec/MultipleExpectations
      expect(src_snippet).not_to be_valid
      expect(src_snippet.errors[:src].join).to include('https://cdn.example.com')

      platform.update!(csp_script_src_text: 'https://cdn.example.com')
      expect(src_snippet).to be_valid
    end

    it 'rejects non https addresses' do
      expect(build(nil, platform:, kind: 'script_src', content: nil, src: 'http://cdn.example.com/a.js'))
        .not_to be_valid
    end
  end

  describe 'audit' do
    it 'records create, enable, update and destroy with the actor' do # rubocop:disable RSpec/MultipleExpectations
      person = create(:better_together_person)
      Current.person = person
      snippet.save!
      snippet.update!(enabled: true)
      snippet.update!(content: 'window.x = 2;')
      snippet.destroy!

      audits = BetterTogether::PlatformSnippetAudit.where(snippet_id: snippet.id).order(:created_at)
      expect(audits.map(&:action)).to eq(%w[created enabled updated destroyed])
      expect(audits.map(&:actor_id).uniq).to eq([person.id])
      expect(audits.third.change_set['content']).to eq(['window.x = 1;', 'window.x = 2;'])
    ensure
      Current.person = nil
    end

    it 'cannot be altered once written' do
      snippet.save!
      audit = BetterTogether::PlatformSnippetAudit.find_by(snippet_id: snippet.id)

      expect { audit.update!(action: 'updated') }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end
  end

  it 'builds imported snippets disabled even when the source says enabled' do
    imported = described_class.build_for_import(platform, name: 'Imp', location: 'head_end', kind: 'script_inline',
                                                          content: 'x()', enabled: true)

    expect(imported.enabled).to be(false)
  end

  it 'positions snippets per location' do
    first = build(nil, platform:).tap(&:save!)
    second = build(nil, platform:, name: 'Two').tap(&:save!)
    body = build(nil, platform:, name: 'Body', location: 'body_end').tap(&:save!)

    expect([first.position, second.position, body.position]).to eq([0, 1, 0])
  end
end
