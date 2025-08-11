# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe ContentHelper, type: :helper do
    describe '#safe_html' do
      it 'escapes dangerous tags' do
        input = "<p>Hello</p><script>alert('xss')</script>"
        output = helper.safe_html(input)
        expect(output).to include('<p>Hello</p>')
        expect(output).not_to include('<script')
      end

      it 'allows permitted markup' do
        input = "<p><strong>Bold</strong> and <a href=\"https://example.com\">link</a></p>"
        output = helper.safe_html(input)
        expect(output).to include('<strong>Bold</strong>')
        expect(output).to include('<a href=\"https://example.com\">link</a>')
      end

      it 'allows youtube iframes' do
        input = '<iframe width="560" height="315" src="https://www.youtube.com/embed/xyz" frameborder="0" allowfullscreen></iframe>'
        output = helper.safe_html(input)
        expect(output).to include('<iframe')
        expect(output).to include('src="https://www.youtube.com/embed/xyz"')
      end

      it 'allows youtube-nocookie iframes' do
        input = '<iframe width="560" height="315" src="https://www.youtube-nocookie.com/embed/xyz" frameborder="0" allowfullscreen></iframe>'
        output = helper.safe_html(input)
        expect(output).to include('<iframe')
        expect(output).to include('src="https://www.youtube-nocookie.com/embed/xyz"')
      end

      it 'strips non-youtube iframes' do
        input = '<iframe src="https://evil.com/video"></iframe>'
        output = helper.safe_html(input)
        expect(output).not_to include('<iframe')
      end
    end
  end
end
