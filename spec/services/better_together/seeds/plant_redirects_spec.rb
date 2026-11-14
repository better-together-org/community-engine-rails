# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Seeds::Plant, '.redirects' do
  let(:platform) { create(:better_together_platform) }
  let(:other_platform) { create(:better_together_platform) }
  let(:dir) { Dir.mktmpdir('seed-packet') }
  let(:records) do
    { redirect: [{ 'key' => 'r1', 'attributes' => { 'from_path' => '/about_us.html', 'to_path' => '/en/about',
                                                    'status' => 301, 'source' => 'seed' } }] }
  end

  before { build_packet(dir, records:) }

  after { FileUtils.remove_entry(dir) }

  def plant(target = platform)
    described_class.call(path: dir, platform: target, apply: true)
  end

  it 'creates the redirect matched on its from_path, with a path no packet key could hold' do
    expect(plant).to include(created: 1, errors: [])

    redirect = BetterTogether::Redirect.find_by!(platform:, from_path: '/about_us.html')
    expect(redirect).to have_attributes(to_path: '/en/about', status: 301)
  end

  it 'finds the same redirect again on a rerun instead of creating a second one' do
    plant

    expect(plant).to include(created: 0, errors: [])
    expect(BetterTogether::Redirect.where(platform:, from_path: '/about_us.html').count).to eq(1)
  end

  it 'keeps the same from_path separate on two platforms' do
    plant
    plant(other_platform)

    expect(BetterTogether::Redirect.where(from_path: '/about_us.html').pluck(:platform_id))
      .to contain_exactly(platform.id, other_platform.id)
  end
end
