# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('app/middleware/better_together/html_comment_stripper').to_s

RSpec.describe BetterTogether::HtmlCommentStripper do
  def respond(body, type: 'text/html; charset=utf-8', status: 200, extra: {})
    app = ->(_env) { [status, { 'content-type' => type, 'content-length' => body.bytesize.to_s }.merge(extra), [body]] }
    described_class.new(app).call({})
  end

  it 'removes plain comments and fixes content-length' do
    status, headers, body = respond('<p>a</p><!-- Branding Element --><p>b</p>')
    expect(body.join).to eq('<p>a</p><p>b</p>')
    expect(headers['content-length']).to eq(body.join.bytesize.to_s)
    expect(status).to eq(200)
  end

  it 'keeps comments inside script, style and pre blocks' do
    html = '<script>/* <!-- x --> */</script><pre><!-- keep --></pre><!-- drop -->'
    expect(respond(html)[2].join).to eq('<script>/* <!-- x --> */</script><pre><!-- keep --></pre>')
  end

  it 'keeps conditional comments' do
    html = '<!--[if IE]><p>ie</p><![endif]-->'
    expect(respond(html)[2].join).to eq(html)
  end

  it 'leaves non-html and encoded responses alone' do
    expect(respond('<!-- a -->', type: 'application/json')[2]).to eq(['<!-- a -->'])
    expect(respond('<!-- a -->', extra: { 'content-encoding' => 'gzip' })[2]).to eq(['<!-- a -->'])
  end
end
