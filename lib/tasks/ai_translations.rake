# frozen_string_literal: true

namespace :better_together do
  namespace :ai_translations do
    namespace :from_en do
      desc 'AI-translate page attributes'
      task page_attrs: :environment do
        Mobility.with_locale(:en) do
          mobility_attrs = BetterTogether::Page.mobility_attributes.excluding('content')
          target_locales = I18n.available_locales.excluding(:en)

          translated_record_count = 0

          pages = BetterTogether::Page.includes(:string_translations).order(:created_at)

          # Initialize the TranslationBot
          BetterTogether::TranslationBot.new

          pages.each do |page|
            puts page.identifier

            translated_attrs = []

            mobility_attrs.each do |attr|
              source_locale_attr = "#{attr}_en"
              puts source_locale_attr

              source_locale_value = page.public_send source_locale_attr
              puts source_locale_value

              target_locales.each do |locale|
                target_locale_attr = "#{attr}_#{locale}"
                puts target_locale_attr

                target_locale_value = page.public_send target_locale_attr
                puts target_locale_value

                next unless source_locale_value.present? && target_locale_value.blank?

                puts "need to translate #{target_locale_attr}"

                # Perform the translation using TranslationBot
                translated_attr_value = nil
                # translated_attr_value = translation_bot.translate(
                #                           source_locale_value,
                #                           target_locale: locale,
                #                           source_locale: 'en'
                #                         )
                puts 'fetched translation:'
                puts translated_attr_value

                translated_attrs << target_locale_attr

                page.public_send "#{target_locale_attr}=", translated_attr_value if translated_attr_value.present?
              end
            end

            next unless translated_attrs.any?

            puts 'updating translations:'
            puts translated_attrs

            puts page.save
            translated_record_count += 1
          end

          puts 'number of translated records:'
          puts translated_record_count
        end
      end

      desc 'AI-translate rich text block attributes'
      task rich_text_block_attrs: :environment do
        Mobility.with_locale(:en) do
          mobility_attrs = BetterTogether::Page.mobility_attributes
          target_locales = I18n.available_locales.excluding(:en)

          translated_record_count = 0
          BetterTogether::Content::Block.load_all_subclasses if Rails.env.development?
          blocks = BetterTogether::Content::RichText.with_translations.order(:created_at)

          translation_bot = BetterTogether::TranslationBot.new

          blocks.each do |block|
            translated_attrs = translate_rich_text_content(block, mobility_attrs, target_locales, translation_bot)

            if translated_attrs.any?
              block.save
              translated_record_count += 1
            end
          end

          puts "number of translated records for RichText blocks: #{translated_record_count}"
        end
      end

      desc 'AI-translate hero block attributes'
      task hero_block_attrs: :environment do
        Mobility.with_locale(:en) do
          mobility_attrs = BetterTogether::Page.mobility_attributes
          target_locales = I18n.available_locales.excluding(:en)

          translated_record_count = 0
          BetterTogether::Content::Block.load_all_subclasses if Rails.env.development?
          blocks = BetterTogether::Content::Hero.includes(:string_translations,
                                                          :rich_text_translations).order(:created_at)

          translation_bot = BetterTogether::TranslationBot.new

          blocks.each do |block|
            translated_attrs = translate_rich_text_content(block, mobility_attrs, target_locales, translation_bot)

            if translated_attrs.any?
              block.save
              translated_record_count += 1
            end
          end

          puts "number of translated records for Hero blocks: #{translated_record_count}"
        end
      end

      desc 'AI-translate nav item attributes'
      task nav_item_attrs: :environment do
        Mobility.with_locale(:en) do
          mobility_attrs = BetterTogether::NavigationItem.mobility_attributes
          puts 'mobility_attrs'
          puts mobility_attrs
          target_locales = I18n.available_locales.excluding(:en)

          translated_record_count = 0

          nav_items = BetterTogether::NavigationItem.includes(:string_translations).where(linkable_id: nil).order(:created_at)

          # Initialize the TranslationBot
          BetterTogether::TranslationBot.new

          nav_items.each do |nav_item|
            puts 'nav_item.identifier'
            puts nav_item.identifier

            translated_attrs = []

            mobility_attrs.each do |attr|
              source_locale_attr = "#{attr}_en"
              puts source_locale_attr

              next unless nav_item.respond_to? source_locale_attr

              source_locale_value = nav_item.public_send source_locale_attr
              puts source_locale_value

              target_locales.each do |locale|
                target_locale_attr = "#{attr}_#{locale}"
                puts target_locale_attr

                target_locale_value = nav_item.public_send target_locale_attr
                puts target_locale_value

                next unless source_locale_value.present? && target_locale_value.blank?

                puts "need to translate #{target_locale_attr}"

                # Perform the translation using TranslationBot
                translated_attr_value = nil
                # translated_attr_value = translation_bot.translate(
                #                           source_locale_value,
                #                           target_locale: locale,
                #                           source_locale: 'en'
                #                         )
                puts 'fetched translation:'
                puts translated_attr_value

                translated_attrs << target_locale_attr

                nav_item.public_send "#{target_locale_attr}=", translated_attr_value if translated_attr_value.present?
              end
            end

            next unless translated_attrs.any?

            puts 'updating translations:'
            puts translated_attrs

            puts nav_item.save
            translated_record_count += 1
          end

          puts 'number of translated records:'
          puts translated_record_count
        end
      end

      def translate_rich_text_content(block, mobility_attrs, target_locales, translation_bot)
        translated_attrs = []

        mobility_attrs.each do |attr|
          source_locale_attr = "#{attr}_en"
          next unless block.respond_to?(source_locale_attr)

          # Extract the rich text content as a string
          source_locale_value = block.public_send(source_locale_attr)&.to_s

          target_locales.each do |locale|
            target_locale_attr = "#{attr}_#{locale}"

            # Check if the translation is already present
            target_locale_value = block.public_send(target_locale_attr)&.to_s

            next unless source_locale_value.present? && target_locale_value.blank?

            # Perform the translation
            translated_attr_value = translation_bot.translate(
              source_locale_value,
              target_locale: locale,
              source_locale: 'en'
            )

            next unless translated_attr_value.present?

            # Set the translated content back to the rich text attribute
            block.public_send("#{target_locale_attr}=", ActionText::Content.new(translated_attr_value))
            translated_attrs << target_locale_attr
          end
        end

        translated_attrs
      end
    end
  end
end
