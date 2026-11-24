# frozen_string_literal: true

require 'rails_helper'

# The default navigation, expressed as a protocol 2.0 packet. Conformance for C6: the packet must
# plant cleanly, rerun without change, keep platforms apart, and describe the same structure that
# NavigationBuilder produces on the host platform.
RSpec.describe 'Navigation seed packet' do # rubocop:disable RSpec/DescribeClass
  let(:packet_path) { BetterTogether::Engine.root.join('config/seeds/better_together/navigation') }
  let(:platform) { create(:better_together_platform) }
  let(:other_platform) { create(:better_together_platform) }

  def plant(target = platform, **)
    BetterTogether::Seeds::Plant.call(path: packet_path, platform: target, apply: true, restrict_sources: true, **)
  end

  # Everything about an item except its position number, which only has to keep the sequence (see `order`).
  def item_shape(item) # rubocop:disable Metrics/AbcSize
    [item.navigation_area.identifier, item.title, item.parent&.title, item.item_type, item.route_name.presence,
     item.privacy, item.visibility_strategy, item.permission_identifier.presence, item.visible, item.protected,
     item.linkable&.title]
  end

  # Titles in display order within each (area, parent) group, as sets per position: the builder ties some items
  # (Events and Community Hub; Privacy Policy and the Contributor Agreements dropdown), and tied items have no
  # defined order. The dropdown is left out because the builder's position for it is the accidental tie.
  def order(scope) # rubocop:disable Metrics/CyclomaticComplexity
    scope.includes(:navigation_area, :parent).group_by { |i| [i.navigation_area.identifier, i.parent&.title] }
         .transform_values do |items|
      items.reject { |i| i.title == 'Contributor Agreements' }.group_by(&:position).sort.map { |_, tied| tied.map(&:title).sort }
    end
  end

  it 'passes protocol validation' do
    packet = BetterTogether::Seeds::Packet.load(packet_path)

    expect(packet.report.errors.map(&:to_h)).to eq([])
  end

  it 'plans without errors and writes nothing on a dry run' do
    report = BetterTogether::Seeds::Plant.call(path: packet_path, platform:, apply: false)

    expect(report[:errors]).to eq([])
    expect(report[:created]).to be > 60
    expect(BetterTogether::NavigationArea.where(platform:)).to be_empty
  end

  it 'plants the areas, pages, blocks and items' do
    report = plant

    expect(report[:errors]).to eq([])
    expect(BetterTogether::NavigationArea.where(platform:).pluck(:identifier))
      .to match_array(%w[platform-header platform-host better-together platform-footer])
    expect(BetterTogether::Page.where(platform:).count).to eq(14)
    expect(BetterTogether::NavigationItem.where(platform:).count).to eq(55)
  end

  it 'changes nothing on a rerun' do
    plant
    counts = [BetterTogether::Page, BetterTogether::NavigationItem, BetterTogether::Content::Block].map(&:count)

    report = plant

    expect(report).to include(created: 0, updated: 0, errors: [])
    expect([BetterTogether::Page, BetterTogether::NavigationItem, BetterTogether::Content::Block].map(&:count)).to eq(counts)
  end

  it 'keeps two platforms apart' do
    plant
    plant(other_platform)

    expect(BetterTogether::Page.i18n.where(platform: other_platform, slug: 'faq').count).to eq(1)
    expect(BetterTogether::Page.i18n.where(platform:, slug: 'faq').count).to eq(1)
    expect(BetterTogether::NavigationItem.where(platform: other_platform).count).to eq(55)
  end

  it 'never rewrites a page a steward edited' do
    plant
    BetterTogether::Page.i18n.find_by!(platform:, slug: 'faq').update!(privacy: 'private')

    plant

    expect(BetterTogether::Page.i18n.find_by!(platform:, slug: 'faq').privacy).to eq('private')
  end

  describe 'published_at: $now' do
    it 'stamps the plant time on creation and leaves it alone on a rerun' do
      plant
      page = BetterTogether::Page.i18n.find_by!(platform:, slug: 'faq')
      stamped = page.published_at
      expect(stamped).to be_within(1.minute).of(Time.current)

      travel(2.days) { expect(plant).to include(created: 0, updated: 0, skipped_edited: 0, errors: []) }
      expect(page.reload.published_at).to eq(stamped)
    end
  end

  describe 'equivalence with NavigationBuilder on the host platform' do
    let(:host) { BetterTogether::Platform.find_by!(host: true) }

    before { plant }

    it 'plants the same navigation items' do
      packet_items = BetterTogether::NavigationItem.where(platform:).includes(:navigation_area, :parent, :linkable).map { |i| item_shape(i) }
      built_items = BetterTogether::NavigationItem.where(platform: host).includes(:navigation_area, :parent, :linkable).map { |i| item_shape(i) }

      expect(packet_items).to match_array(built_items)
    end

    it 'keeps the builder\'s order of items' do
      built = order(BetterTogether::NavigationItem.where(platform: host))
      planted = order(BetterTogether::NavigationItem.where(platform:))

      expect(planted.keys).to match_array(built.keys)
      built.each { |group, titles| expect(planted[group]).to eq(titles), "order differs in #{group.inspect}" }
    end

    it 'plants the same pages and blocks' do
      shape = lambda do |page|
        [page.slug, page.title, page.layout, page.protected, page.privacy, page.published_at.present?,
         page.page_blocks.order(:position).map { |pb| [pb.block.class.name, pb.block.try(:template_path).presence] }]
      end
      packet_pages = BetterTogether::Page.where(platform:).map(&shape)
      slugs = packet_pages.map(&:first)
      built_pages = BetterTogether::Page.i18n.where(platform: host, slug: slugs).map(&shape)

      expect(packet_pages).to match_array(built_pages)
    end
  end
end
