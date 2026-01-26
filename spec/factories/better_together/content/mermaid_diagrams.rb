# frozen_string_literal: true

FactoryBot.define do
  factory :better_together_content_mermaid_diagram, class: 'BetterTogether::Content::MermaidDiagram' do
    association :creator, factory: :better_together_person
    privacy { 'public' }
    identifier { "mermaid-diagram-#{SecureRandom.hex(4)}" }

    diagram_source do
      <<~MERMAID
        graph TD
          A[#{Faker::Lorem.word.capitalize}] --> B[#{Faker::Lorem.word.capitalize}]
          B --> C{#{Faker::Lorem.word.capitalize}?}
          C -->|Yes| D[#{Faker::Lorem.word.capitalize}]
          C -->|No| E[#{Faker::Lorem.word.capitalize}]
      MERMAID
    end

    caption { Faker::Lorem.sentence }
    theme { 'default' }
    auto_height { true }

    trait :with_dark_theme do
      theme { 'dark' }
    end

    trait :with_forest_theme do
      theme { 'forest' }
    end

    trait :with_neutral_theme do
      theme { 'neutral' }
    end

    trait :with_caption do
      caption { Faker::Lorem.paragraph }
    end

    trait :without_caption do
      caption { nil }
    end

    trait :fixed_height do
      auto_height { false }
    end

    trait :from_file do
      diagram_source { nil }
      diagram_file_path { 'docs/diagrams/source/example.mmd' }
    end

    trait :flowchart do
      diagram_source do
        <<~MERMAID
          flowchart LR
            Start --> Process
            Process --> Decision{Check}
            Decision -->|Pass| Success
            Decision -->|Fail| Error
            Error --> Process
            Success --> End
        MERMAID
      end
    end

    trait :sequence_diagram do
      diagram_source do
        <<~MERMAID
          sequenceDiagram
            participant User
            participant Server
            participant Database
            User->>Server: Request Data
            Server->>Database: Query
            Database-->>Server: Results
            Server-->>User: Response
        MERMAID
      end
    end

    trait :class_diagram do
      diagram_source do
        <<~MERMAID
          classDiagram
            class Animal {
              +String name
              +int age
              +makeSound()
            }
            class Dog {
              +bark()
            }
            Animal <|-- Dog
        MERMAID
      end
    end

    trait :state_diagram do
      diagram_source do
        <<~MERMAID
          stateDiagram-v2
            [*] --> Idle
            Idle --> Processing
            Processing --> Complete
            Processing --> Error
            Error --> Idle
            Complete --> [*]
        MERMAID
      end
    end

    trait :gantt_chart do
      diagram_source do
        <<~MERMAID
          gantt
            title Project Timeline
            dateFormat YYYY-MM-DD
            section Phase 1
            Task 1: 2024-01-01, 30d
            Task 2: 2024-02-01, 20d
        MERMAID
      end
    end
  end
end
