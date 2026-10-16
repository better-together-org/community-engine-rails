# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Post community chip' do
  let(:locale) { I18n.default_locale }
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let!(:community) { create(:better_together_community, privacy: 'public', name: 'Chip Visible Community') }
  let!(:post_record) do
    create(:better_together_post, title: 'Chip Post', community:, platform: host_platform,
                                  privacy: 'public', published_at: 1.day.ago)
  end

  before { configure_host_platform }

  def chip_nodes
    Nokogiri::HTML(response.body).css('.community-chip')
  end

  def chip_names
    chip_nodes.map { |node| node.at_css('.community-chip-name').text.strip }
  end

  it 'shows the community on the posts index card' do
    get better_together.posts_path(locale:)

    expect(chip_names).to include('Chip Visible Community')
    expect(chip_nodes.first['href']).to include(community.slug)
  end

  it 'shows the community on the post list view' do
    get better_together.posts_path(locale:, view_type: 'list')

    expect(chip_names).to include('Chip Visible Community')
  end

  it 'shows the community on the post table view' do
    get better_together.posts_path(locale:, view_type: 'table')

    expect(chip_names).to include('Chip Visible Community')
  end

  it 'shows the community on the post show page' do
    get better_together.post_path(post_record, locale:)

    expect(response).to have_http_status(:ok)
    expect(chip_names).to include('Chip Visible Community')
  end

  it 'distinguishes the chip with the image, a trailing icon, a screen reader label and a tooltip' do
    get better_together.post_path(post_record, locale:)

    chip = chip_nodes.first
    expect(chip.at_css('img.profile-image')).to be_present
    expect(chip.at_css('i.fa-people-group')['aria-hidden']).to eq('true')
    expect(chip.element_children.last.name).to eq('i')
    expect(chip.at_css('.visually-hidden').text).to eq('Community:')
    expect(chip['title']).to eq('Posted in the Chip Visible Community community')
    expect(chip['data-bs-toggle']).to eq('tooltip')
  end

  it 'omits the chip on the index when the page is scoped to that community' do
    get better_together.posts_path(locale:, community_id: community.slug)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Chip Post')
    expect(chip_nodes).to be_empty
  end

  it 'omits the chip when the viewer cannot see the community', :no_auth do
    community.update_columns(privacy: 'private') # rubocop:disable Rails/SkipsModelValidations
    logout
    get better_together.post_path(post_record, locale:)

    expect(chip_nodes).to be_empty
  end
end
