namespace :better_together do
  namespace :ai_translations do
    namespace :from_en do
      desc 'AI-translate page attributes'
      task page_attrs: :environment do
        Mobility.with_locale(:en) do
          mobility_attrs = BetterTogether::Page.mobility_attributes.excluding('content')
          target_locales = I18n.available_locales.excluding(:en)

          pages = BetterTogether::Page.includes(:string_translations).limit(1).order(:created_at)

          # Initialize the TranslationBot
          translation_bot = BetterTogether::TranslationBot.new

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

                if source_locale_value.present? && target_locale_value.blank?
                  puts "need to translate #{target_locale_attr}"

                  # Perform the translation using TranslationBot
                  translated_attr_value = translation_bot.translate(
                                            source_locale_value,
                                            target_locale: locale,
                                            source_locale: 'en'
                                          )
                  puts "fetched translation:"
                  puts translated_attr_value

                  translated_attrs << target_locale_attr

                  if translated_attr_value.present?
                    page.public_send "#{target_locale_attr}=", translated_attr_value
                  end
                end
              end
            end

            if translated_attrs.any?
              puts "updating translations:"
              puts translated_attrs

              puts page.save
            end
          end
        end
      end

      desc 'AI-translate block attributes'
      task block_attrs: :environment do

      end
    end
  end
end
