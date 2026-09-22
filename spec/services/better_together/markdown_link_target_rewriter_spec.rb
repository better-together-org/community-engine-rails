# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::MarkdownLinkTargetRewriter, type: :service do
  def rewrite(html)
    described_class.new(html).call
  end

  before do
    # Ensure no host platform is found so all HTTP links are treated as external
    allow(BetterTogether::Platform).to receive(:find_by).with(host: true).and_return(nil)
  end

  describe 'external HTTP links' do
    it 'adds target=_blank to an external http link' do
      html = '<a href="http://example.com">visit</a>'
      result = rewrite(html)
      expect(result).to include('target="_blank"')
    end

    it 'adds rel noopener noreferrer to external links' do
      html = '<a href="https://example.com">visit</a>'
      result = rewrite(html)
      expect(result).to include('noopener')
      expect(result).to include('noreferrer')
    end

    it 'preserves existing rel tokens while adding security tokens' do
      html = '<a href="https://example.com" rel="sponsored">visit</a>'
      result = rewrite(html)
      expect(result).to include('sponsored')
      expect(result).to include('noopener')
    end
  end

  describe 'internal and non-HTTP links' do
    it 'removes target=_blank from internal path links' do
      html = '<a href="/about" target="_blank">about</a>'
      result = rewrite(html)
      expect(result).not_to include('target="_blank"')
    end

    it 'removes security rel tokens from internal path links' do
      html = '<a href="/about" rel="noopener noreferrer">about</a>'
      result = rewrite(html)
      expect(result).not_to include('noopener')
    end

    it 'leaves anchor links unchanged' do
      html = '<a href="#section">jump</a>'
      result = rewrite(html)
      expect(result).not_to include('target')
    end

    it 'leaves mailto links unchanged' do
      html = '<a href="mailto:test@example.com">email</a>'
      result = rewrite(html)
      expect(result).not_to include('target')
    end

    it 'leaves tel links unchanged' do
      html = '<a href="tel:+15551234567">call</a>'
      result = rewrite(html)
      expect(result).not_to include('target')
    end
  end

  describe 'edge cases' do
    it 'returns blank input unchanged' do
      expect(rewrite('')).to eq('')
    end

    it 'handles a link with an invalid URI without raising' do
      html = '<a href="not a valid uri [test]">link</a>'
      expect { rewrite(html) }.not_to raise_error
    end

    it 'handles links with no href attribute without raising' do
      html = '<a name="anchor">anchor</a>'
      expect { rewrite(html) }.not_to raise_error
    end
  end
end
