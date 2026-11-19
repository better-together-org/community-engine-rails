# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('app/middleware/better_together/immutable_asset_cache').to_s

RSpec.describe BetterTogether::ImmutableAssetCache do
  def call(path, headers = {}, status = 200)
    app = ->(_env) { [status, headers.dup, ['x']] }
    described_class.new(app).call('PATH_INFO' => path)[1]
  end

  it 'adds immutable caching to fingerprinted assets' do
    expect(call('/assets/application-0123456789abcdef.css')['cache-control']).to include('immutable')
  end

  it 'does not touch non-fingerprinted paths, existing headers or errors' do
    expect(call('/assets/application.css')).not_to have_key('cache-control')
    expect(call('/assets/a-0123456789abcdef.js', { 'cache-control' => 'no-store' })['cache-control']).to eq('no-store')
    expect(call('/assets/a-0123456789abcdef.js', {}, 404)).not_to have_key('cache-control')
  end
end
