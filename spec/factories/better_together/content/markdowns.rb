# frozen_string_literal: true

FactoryBot.define do
  factory :content_markdown, class: 'BetterTogether::Content::Markdown', aliases: [:markdown_block] do
    markdown_source { Faker::Markdown.random }

    trait :with_source do
      markdown_source do
        <<~MD
          # #{Faker::Lorem.sentence}

          #{Faker::Lorem.paragraph}

          ## #{Faker::Lorem.words(number: 3).join(' ').capitalize}

          #{Faker::Lorem.paragraphs(number: 2).join("\n\n")}

          - #{Faker::Lorem.sentence}
          - #{Faker::Lorem.sentence}
          - #{Faker::Lorem.sentence}

          **#{Faker::Lorem.sentence}**

          *#{Faker::Lorem.sentence}*
        MD
      end
      markdown_file_path { nil }
    end

    trait :with_file do
      markdown_source { nil }
      markdown_file_path do
        file_path = Rails.root.join("spec/fixtures/files/factory_markdown_#{SecureRandom.hex(4)}.md")
        FileUtils.mkdir_p(File.dirname(file_path))
        File.write(file_path, Faker::Markdown.random)
        file_path.to_s
      end

      after(:create) do |markdown|
        # Clean up the file after tests complete
        FileUtils.rm_f(markdown.markdown_file_path) if markdown.markdown_file_path.present?
      end
    end

    trait :simple do
      markdown_source { "# #{Faker::Lorem.sentence}\n\n#{Faker::Lorem.paragraph}" }
      markdown_file_path { nil }
    end

    trait :with_table do
      markdown_source do
        <<~MD
          # Data Table

          | Column 1 | Column 2 | Column 3 |
          |----------|----------|----------|
          | Data 1   | Data 2   | Data 3   |
          | Value A  | Value B  | Value C  |
        MD
      end
      markdown_file_path { nil }
    end

    trait :with_code do
      markdown_source do
        <<~MD
          # Code Example

          Here's some Ruby code:

          ```ruby
          def hello(name)
            puts "Hello, \#{name}!"
          end
          ```
        MD
      end
      markdown_file_path { nil }
    end

    trait :with_links do
      markdown_source do
        <<~MD
          # Links

          Check out [this external link](https://example.com) and [this internal link](/about).
        MD
      end
      markdown_file_path { nil }
    end

    trait :empty do
      markdown_source { '' }
      markdown_file_path { nil }
    end
  end
end
