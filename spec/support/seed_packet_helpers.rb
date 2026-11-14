# frozen_string_literal: true

# Builds protocol 2.0 packet directories under a tmpdir from plain hashes.
# rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/ParameterLists
module SeedPacketHelpers
  def build_packet(dir, id: 'test-packet', mode: 'add_only', records: {}, deletes: [], depends: [], extra_packet: {})
    FileUtils.mkdir_p(File.join(dir, 'records'))
    files = records.keys.map { |type| "records/#{type}.yml" }
    envelope = {
      'better_together' => {
        'version' => '2.0',
        'seed' => { 'type' => 'BetterTogether::Seed', 'identifier' => id, 'created_by' => 'spec',
                    'created_at' => '2026-11-13T00:00:00Z', 'description' => 'spec packet', 'origin' => {} },
        'seed_pack' => { 'schema_version' => '1.0', 'pack_type' => 'navigation', 'install_tier' => 'optional',
                         'dependencies' => depends },
        'packet' => { 'id' => id, 'version' => '1.0.0', 'mode' => mode, 'default_locale' => 'en',
                      'locales' => %w[en fr], 'records' => files }.merge(extra_packet)
      }
    }
    envelope['better_together']['deletes'] = deletes if deletes.any?
    File.write(File.join(dir, 'packet.yml'), envelope.to_yaml)
    records.each do |type, list|
      File.write(File.join(dir, "records/#{type}.yml"), { 'version' => '2.0', 'type' => type.to_s, 'records' => list }.to_yaml)
    end
    dir
  end

  def nav_records(title: 'Home')
    {
      navigation_area: [{ 'key' => 'main-nav', 'attributes' => { 'visible' => true },
                          'translations' => { 'en' => { 'name' => 'Packet Navigation' } } }],
      navigation_item: [
        { 'key' => 'nav-home', 'attributes' => { 'item_type' => 'link', 'url' => '/', 'visible' => true, 'privacy' => 'private' },
          'translations' => { 'en' => { 'title' => title }, 'fr' => { 'title' => 'Accueil' } },
          'refs' => { 'navigation_area' => 'navigation_area:main-nav' }, 'position' => 0 },
        { 'key' => 'nav-about', 'attributes' => { 'item_type' => 'link', 'url' => '/about', 'visible' => true, 'privacy' => 'private' },
          'translations' => { 'en' => { 'title' => 'About' } },
          'refs' => { 'navigation_area' => 'navigation_area:main-nav', 'parent' => 'navigation_item:nav-home' }, 'position' => 1 }
      ]
    }
  end
end

# rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/ParameterLists

RSpec.configure { |config| config.include SeedPacketHelpers }
