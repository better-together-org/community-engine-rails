# frozen_string_literal: true

namespace :better_together do # rubocop:todo Metrics/BlockLength
  namespace :migrate_data do # rubocop:todo Metrics/BlockLength
    desc 'migrate unlisted privacy to private'
    task unlisted_privacies_to_private: :environment do
      BetterTogether::Privacy.included_in_models.each do |model|
        model.where(privacy: 'unlisted').update_all(privacy: 'private')
      end
    end

    desc 'Migrate nav item route name values from _path to _url'
    task nav_item_route_name_to_url: :environment do
      nav_items = BetterTogether::NavigationItem.where('route_name ILIKE ?', '%_path')

      puts nav_items.size

      nav_items.each do |nav_item|
        nav_item.update(route_name: nav_item.route_name.sub('_path', '_url'))
      end
    end

    desc 'Migrate existing page contents to blocks'
    task page_contents_to_blocks: :environment do
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

      Mobility.with_locale(:en) do
        pages.each do |page|
          next if page.page_blocks.any?

          page_block = page.page_blocks.build
          block = page_block.build_block(type: 'BetterTogether::Content::RichText',
                                         creator_id: BetterTogether::Person.first&.id)

          content_attrs.each do |attr|
            block.public_send("#{attr}=", page.public_send(attr))
          end

          page_block.save!
        end
      end
    end

    desc 'migrates html content to html translatable text field'
    task html_block_translatable_html: :environment do
      Mobility.with_locale(:en) do
        BetterTogether::Content::Html.all.each do |html|
          html.content = html.html_content

          html.save
        end
      end
    end

    desc 'migrates unencrypted message content to encrypted rich text'
    task unencrypted_messages: :environment do
      BetterTogether::Message.all.each do |message|
        next if message.content.persisted? || message[:content].nil?

        message.content = message[:content]

        message.save
      end
    end
  end
end
