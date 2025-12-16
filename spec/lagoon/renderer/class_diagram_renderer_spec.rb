# frozen_string_literal: true

RSpec.describe Lagoon::Renderer::ClassDiagramRenderer do
  subject(:renderer) { described_class.new(direction: "TB") }

  describe "#render" do
    let(:parsed_data) do
      {
        classes: [
          {
            name: "User",
            abstract: false,
            attributes: [
              { name: "id", type: :integer, visibility: "+" },
              { name: "name", type: :string, visibility: "+" }
            ],
            methods: [
              { name: "full_name", visibility: "+", return_type: nil }
            ]
          },
          {
            name: "ApplicationRecord",
            abstract: true,
            attributes: [],
            methods: []
          }
        ],
        relationships: [
          {
            source: "ApplicationRecord",
            target: "User",
            type: :inheritance,
            label: nil,
            source_cardinality: nil,
            target_cardinality: nil
          }
        ]
      }
    end

    it "generates valid Mermaid class diagram" do
      output = renderer.render(parsed_data)

      expect(output).to include("classDiagram")
      expect(output).to include("direction TB")
      expect(output).to include("class User {")
      expect(output).to include("+Integer id")
      expect(output).to include("+String name")
      expect(output).to include("+full_name()")
      expect(output).to include("class ApplicationRecord {")
      expect(output).to include("<<abstract>>")
      expect(output).to include("ApplicationRecord <|-- User")
    end

    it "handles empty classes" do
      empty_data = { classes: [], relationships: [] }
      output = renderer.render(empty_data)

      expect(output).to include("classDiagram")
      expect(output).to include("direction TB")
    end

    it "handles different relationship types" do
      data = {
        classes: [
          { name: "User", abstract: false, attributes: [], methods: [] },
          { name: "Post", abstract: false, attributes: [], methods: [] }
        ],
        relationships: [
          {
            source: "User",
            target: "Post",
            type: :association,
            label: "has_many posts",
            source_cardinality: "1",
            target_cardinality: "*"
          }
        ]
      }

      output = renderer.render(data)
      expect(output).to include('User "1" --> "*" Post : has_many posts')
    end

    it "handles composition relationships" do
      data = {
        classes: [
          { name: "Car", abstract: false, attributes: [], methods: [] },
          { name: "Engine", abstract: false, attributes: [], methods: [] }
        ],
        relationships: [
          {
            source: "Car",
            target: "Engine",
            type: :composition,
            label: nil,
            source_cardinality: nil,
            target_cardinality: nil
          }
        ]
      }

      output = renderer.render(data)
      expect(output).to include("Car *-- Engine")
    end

    it "handles aggregation relationships" do
      data = {
        classes: [
          { name: "Team", abstract: false, attributes: [], methods: [] },
          { name: "Player", abstract: false, attributes: [], methods: [] }
        ],
        relationships: [
          {
            source: "Team",
            target: "Player",
            type: :aggregation,
            label: nil,
            source_cardinality: nil,
            target_cardinality: nil
          }
        ]
      }

      output = renderer.render(data)
      expect(output).to include("Team o-- Player")
    end
  end
end
