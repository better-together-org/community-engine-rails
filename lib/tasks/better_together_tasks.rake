# frozen_string_literal: true

# lib/tasks/better_together_tasks.rake
namespace :better_together do # rubocop:todo Metrics/BlockLength
  desc 'Load seed data for BetterTogether'
  task load_seed: :environment do
    load BetterTogether::Engine.root.join('db', 'seeds.rb')
  end

  desc 'Generate access control'
  task generate_access_control: :environment do
    BetterTogether::AccessControlBuilder.build(clear: true)
  end

  desc 'Generate default navigation areas, items, and pages'
  task generate_navigation_and_pages: :environment do
    BetterTogether::NavigationBuilder.build(clear: true)
  end

  desc 'Generate setup wizard and step definitions'
  task generate_setup_wizard: :environment do
    BetterTogether::SetupWizardBuilder.build(clear: true)
  end

  desc 'Migrate existing page contents to blocks'
  task migrate_page_contents_to_blocks: :environment do
    puts '======================'

    content_translations = ActionText::RichText.where(
      record_type: 'BetterTogether::Page',
      name: 'content',
      locale: I18n.available_locales
    )

    pages = BetterTogether::Page.where(id: content_translations.pluck(:record_id))

    puts pages.size, 'pages'
    content_attrs = BetterTogether::Page.localized_attribute_list.select do |attribute|
      attribute.to_s.start_with?('content')
    end

    pages.each do |page|
      next if page.page_blocks.any?

      page_block = page.page_blocks.build
      block = page_block.build_block(type: 'BetterTogether::Content::RichText')

      content_attrs.each do |attr|
        block.public_send("#{attr}=", page.public_send(attr))
      end

      page_block.save!
    end
  end
end
