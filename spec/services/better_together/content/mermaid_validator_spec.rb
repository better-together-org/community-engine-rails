# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Content::MermaidValidator do
  describe '#valid?' do
    context 'with valid mermaid diagrams' do
      it 'validates a basic flowchart' do
        content = <<~MERMAID
          graph TD
            A[Start] --> B[Process]
            B --> C[End]
        MERMAID
        validator = described_class.new(content)
        expect(validator).to be_valid
        expect(validator.errors).to be_empty
      end

      it 'validates a sequence diagram' do
        content = <<~MERMAID
          sequenceDiagram
            Alice->>John: Hello John, how are you?
            John-->>Alice: Great!
        MERMAID
        validator = described_class.new(content)
        expect(validator).to be_valid
      end

      it 'validates a class diagram' do
        content = <<~MERMAID
          classDiagram
            Animal <|-- Duck
            Animal : +int age
        MERMAID
        validator = described_class.new(content)
        expect(validator).to be_valid
      end

      it 'validates a state diagram' do
        content = <<~MERMAID
          stateDiagram-v2
            [*] --> Still
            Still --> Moving
        MERMAID
        validator = described_class.new(content)
        expect(validator).to be_valid
      end

      it 'validates an ER diagram' do
        content = <<~MERMAID
          erDiagram
            CUSTOMER ||--o{ ORDER : places
        MERMAID
        validator = described_class.new(content)
        expect(validator).to be_valid
      end

      it 'validates a pie chart' do
        content = <<~MERMAID
          pie title Pets adopted by volunteers
            "Dogs" : 386
            "Cats" : 85
        MERMAID
        validator = described_class.new(content)
        expect(validator).to be_valid
      end

      it 'validates a gantt chart' do
        content = <<~MERMAID
          gantt
            title A Gantt Diagram
            dateFormat  YYYY-MM-DD
            section Section
            A task           :a1, 2014-01-01, 30d
        MERMAID
        validator = described_class.new(content)
        expect(validator).to be_valid
      end

      it 'validates graph with valid directions' do
        %w[TB TD BT RL LR].each do |direction|
          content = "graph #{direction}\n  A --> B"
          validator = described_class.new(content)
          expect(validator).to be_valid
        end
      end

      it 'validates flowchart with valid directions' do
        %w[TB TD BT RL LR].each do |direction|
          content = "flowchart #{direction}\n  A --> B"
          validator = described_class.new(content)
          expect(validator).to be_valid
        end
      end
    end

    context 'with invalid mermaid diagrams' do
      it 'rejects blank content' do
        validator = described_class.new('')
        expect(validator).not_to be_valid
        expect(validator.errors).to include('Content cannot be blank')
      end

      it 'rejects nil content' do
        validator = described_class.new(nil)
        expect(validator).not_to be_valid
        expect(validator.errors).to include('Content cannot be blank')
      end

      it 'rejects content with only whitespace' do
        validator = described_class.new("   \n  \n  ")
        expect(validator).not_to be_valid
        expect(validator.errors).to include('Content cannot be blank')
      end

      it 'rejects invalid diagram type' do
        content = <<~MERMAID
          invalidType
            A --> B
        MERMAID
        validator = described_class.new(content)
        expect(validator).not_to be_valid
        expect(validator.errors.first).to include('Invalid diagram type')
      end

      it 'rejects graph with invalid direction' do
        content = <<~MERMAID
          graph INVALID
            A --> B
        MERMAID
        validator = described_class.new(content)
        expect(validator).not_to be_valid
        expect(validator.errors.first).to include('Invalid graph direction')
      end

      it 'rejects flowchart with invalid direction' do
        content = <<~MERMAID
          flowchart XYZ
            A --> B
        MERMAID
        validator = described_class.new(content)
        expect(validator).not_to be_valid
        expect(validator.errors.first).to include('Invalid graph direction')
      end

      it 'rejects diagram with only type declaration' do
        content = 'graph TD'
        validator = described_class.new(content)
        expect(validator).not_to be_valid
        expect(validator.errors).to include('Diagram appears to be empty')
      end
    end

    context 'with Mermaid configuration directives and comments' do
      it 'validates diagram with init config on first line' do
        content = <<~MERMAID
          %%{init: {"flowchart": {"diagramPadding": 40, "nodeSpacing": 160, "rankSpacing": 120}}}%%
          graph TD
            A[Start] --> B[End]
        MERMAID

        validator = described_class.new(content)
        expect(validator).to be_valid
        expect(validator.errors).to be_empty
      end

      it 'validates diagram with single-line comment before diagram type' do
        content = <<~MERMAID
          %% This is a comment explaining the diagram
          flowchart LR
            A --> B
        MERMAID

        validator = described_class.new(content)
        expect(validator).to be_valid
      end

      it 'validates diagram with multiple leading comments' do
        content = <<~MERMAID
          %% System Architecture Diagram
          %% Generated: 2026-01-18
          %% Author: Platform Team

          graph TD
            A --> B
        MERMAID

        validator = described_class.new(content)
        expect(validator).to be_valid
      end

      it 'validates diagram with both config and comments' do
        content = <<~MERMAID
          %%{init: {"theme": "dark"}}%%
          %% User Authentication Flow
          flowchart TD
            A[User] --> B[System]
        MERMAID

        validator = described_class.new(content)
        expect(validator).to be_valid
      end

      it 'validates class diagram with leading comment' do
        content = <<~MERMAID
          %% Models & Concerns class diagram
          classDiagram
            direction TB
            class User {
              +String name
              +login()
            }
        MERMAID

        validator = described_class.new(content)
        expect(validator).to be_valid
      end

      it 'rejects diagram with only comments and no diagram type' do
        content = <<~MERMAID
          %% Just a comment
          %% Another comment
          %% No actual diagram
        MERMAID

        validator = described_class.new(content)
        expect(validator).not_to be_valid
        expect(validator.errors).to include('Missing diagram type declaration')
      end

      it 'rejects diagram with config but invalid type' do
        content = <<~MERMAID
          %%{init: {"theme": "dark"}}%%
          invalidDiagramType
            A --> B
        MERMAID

        validator = described_class.new(content)
        expect(validator).not_to be_valid
        expect(validator.errors.first).to include('Invalid diagram type')
      end
    end
  end
end
