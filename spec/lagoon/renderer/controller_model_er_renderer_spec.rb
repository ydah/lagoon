# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/lagoon/renderer/base_renderer"
require_relative "../../../lib/lagoon/renderer/controller_model_er_renderer"

RSpec.describe Lagoon::Renderer::ControllerModelErRenderer do
  let(:renderer) { described_class.new }

  describe "#render" do
    context "with basic relationships" do
      it "renders a simple controller-model relationship" do
        parsed_data = {
          relationships: [
            { controller: "UsersController", model: "User", actions: ["index", "show"] }
          ]
        }

        result = renderer.render(parsed_data)

        expect(result).to include("classDiagram")
        expect(result).to include("UsersController ..> User : index, show")
      end

      it "renders multiple relationships for one controller" do
        parsed_data = {
          relationships: [
            { controller: "UsersController", model: "User", actions: ["index", "show"] },
            { controller: "UsersController", model: "Role", actions: ["index"] },
            { controller: "UsersController", model: "Post", actions: ["show"] }
          ]
        }

        result = renderer.render(parsed_data)

        expect(result).to include("classDiagram")
        expect(result).to include("UsersController ..> User : index, show")
        expect(result).to include("UsersController ..> Role : index")
        expect(result).to include("UsersController ..> Post : show")
      end

      it "renders relationships for multiple controllers" do
        parsed_data = {
          relationships: [
            { controller: "UsersController", model: "User", actions: ["index"] },
            { controller: "PostsController", model: "Post", actions: ["index"] },
            { controller: "PostsController", model: "Comment", actions: ["show"] }
          ]
        }

        result = renderer.render(parsed_data)

        expect(result).to include("UsersController ..> User : index")
        expect(result).to include("PostsController ..> Post : index")
        expect(result).to include("PostsController ..> Comment : show")
      end
    end

    context "with show_actions option" do
      it "shows action names when show_actions is true" do
        renderer_with_actions = described_class.new(show_actions: true)
        parsed_data = {
          relationships: [
            { controller: "UsersController", model: "User", actions: ["index", "show", "create"] }
          ]
        }

        result = renderer_with_actions.render(parsed_data)

        expect(result).to include("create, index, show")
      end

      it "hides action names when show_actions is false" do
        renderer_without_actions = described_class.new(show_actions: false)
        parsed_data = {
          relationships: [
            { controller: "UsersController", model: "User", actions: ["index", "show", "create"] }
          ]
        }

        result = renderer_without_actions.render(parsed_data)

        expect(result).to include("UsersController ..> User")
        expect(result).not_to include("User :")
        expect(result).not_to include("index")
        expect(result).not_to include("show")
        expect(result).not_to include("create")
      end
    end

    context "with edge cases" do
      it "handles empty relationships" do
        parsed_data = { relationships: [] }

        result = renderer.render(parsed_data)

        expect(result).to eq("classDiagram\n    direction TB")
      end

      it "handles relationships with no actions" do
        parsed_data = {
          relationships: [
            { controller: "UsersController", model: "User", actions: [] }
          ]
        }

        result = renderer.render(parsed_data)

        expect(result).to include("UsersController ..> User")
        expect(result).not_to include("User :")
      end

      it "handles namespaced controllers" do
        parsed_data = {
          relationships: [
            { controller: "Admin::UsersController", model: "User", actions: ["index"] }
          ]
        }

        result = renderer.render(parsed_data)

        expect(result).to include('class Admin_UsersController["Admin::UsersController"]')
        expect(result).to include("Admin_UsersController ..> User")
      end

      it "escapes special characters in controller names" do
        parsed_data = {
          relationships: [
            { controller: "API::V1::UsersController", model: "User", actions: ["index"] }
          ]
        }

        result = renderer.render(parsed_data)

        expect(result).to include("API::V1::UsersController")
      end
    end

    context "with direction option" do
      it "accepts direction option (TB)" do
        renderer_tb = described_class.new(direction: "TB")
        expect(renderer_tb.direction).to eq("TB")
      end

      it "accepts direction option (LR)" do
        renderer_lr = described_class.new(direction: "LR")
        expect(renderer_lr.direction).to eq("LR")
      end

      it "uses TB as default direction" do
        expect(renderer.direction).to eq("TB")
      end
    end

    context "with complex actions" do
      it "handles multiple actions in alphabetical order" do
        parsed_data = {
          relationships: [
            {
              controller: "UsersController",
              model: "User",
              actions: ["create", "destroy", "edit", "index", "new", "show", "update"]
            }
          ]
        }

        result = renderer.render(parsed_data)

        expect(result).to include("create, destroy, edit, index, new, show, update")
      end
    end

    describe "output format" do
      it "generates valid Mermaid class diagram syntax" do
        parsed_data = {
          relationships: [
            { controller: "UsersController", model: "User", actions: ["index", "show"] },
            { controller: "PostsController", model: "Post", actions: ["index"] }
          ]
        }

        result = renderer.render(parsed_data)

        lines = result.split("\n")
        expect(lines.first).to eq("classDiagram")
        expect(lines).to include("    UsersController ..> User : index, show")
        expect(lines).to include("    PostsController ..> Post : index")
      end
    end
  end
end
