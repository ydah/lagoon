# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require_relative "../../../lib/lagoon/analyzer/ast_model_reference_analyzer"
require_relative "../../../lib/lagoon/parser/controller_model_parser"

RSpec.describe Lagoon::Analyzer::AstModelReferenceAnalyzer do
  let(:analyzer) { described_class.new }

  describe "Integration with ControllerModelParser" do
    let(:temp_controller_file) { Tempfile.new(["users_controller", ".rb"]) }

    after { temp_controller_file.unlink }

    it "analyzes a realistic controller file" do
      temp_controller_file.write(<<~RUBY)
        class UsersController < ApplicationController
          def index
            @users = User.where(active: true)
            @roles = Role.all
          end

          def show
            @user = User.find(params[:id])
            @posts = @user.posts
            @profile = @user.profile
          end

          def create
            @user = User.new(user_params)
            if @user.save
              redirect_to @user
            else
              render :new
            end
          end

          private

          def user_params
            params.require(:user).permit(:name, :email)
          end
        end
      RUBY
      temp_controller_file.rewind

      result = analyzer.analyze(temp_controller_file.path, ["index", "show", "create"])

      expect(result["index"].to_a).to match_array(%w[User Role])
      expect(result["show"].to_a).to match_array(%w[User Post Profile])
      expect(result["create"].to_a).to include("User")
      expect(result.keys).not_to include("user_params") # private methods not analyzed
    end

    it "handles namespaced controllers" do
      temp_controller_file.write(<<~RUBY)
        module Admin
          class PostsController < ApplicationController
            def index
              @posts = Post.published
              @categories = Category.all
            end
          end
        end
      RUBY
      temp_controller_file.rewind

      result = analyzer.analyze(temp_controller_file.path, ["index"])

      expect(result["index"].to_a).to match_array(%w[Post Category])
    end

    it "handles controllers with complex logic" do
      temp_controller_file.write(<<~RUBY)
        class PostsController < ApplicationController
          def show
            @post = Post.find(params[:id])

            if current_user.admin?
              @all_comments = @post.comments
            else
              @all_comments = @post.comments.approved
            end

            @related_posts = Post.where(category_id: @post.category_id).limit(5)
          end
        end
      RUBY
      temp_controller_file.rewind

      result = analyzer.analyze(temp_controller_file.path, ["show"])

      expect(result["show"].to_a).to include("Post", "Comment", "User")
    end

    it "handles empty actions" do
      temp_controller_file.write(<<~RUBY)
        class PagesController < ApplicationController
          def home
            # Static page, no models
          end

          def about
            render :about
          end
        end
      RUBY
      temp_controller_file.rewind

      result = analyzer.analyze(temp_controller_file.path, ["home", "about"])

      expect(result["home"].to_a).to be_empty
      expect(result["about"].to_a).to be_empty
    end
  end
end

RSpec.describe Lagoon::Parser::ControllerModelParser do
  let(:parser) { described_class.new }

  describe "#aggregate_relationships" do
    it "groups relationships by controller and model" do
      relationships = [
        { controller: "UsersController", action: "index", model: "User" },
        { controller: "UsersController", action: "show", model: "User" },
        { controller: "UsersController", action: "create", model: "User" },
        { controller: "UsersController", action: "index", model: "Role" },
        { controller: "PostsController", action: "index", model: "Post" }
      ]

      result = parser.send(:aggregate_relationships, relationships)

      expect(result).to contain_exactly(
        { controller: "UsersController", model: "User", actions: %w[create index show] },
        { controller: "UsersController", model: "Role", actions: ["index"] },
        { controller: "PostsController", model: "Post", actions: ["index"] }
      )
    end

    it "deduplicates actions" do
      relationships = [
        { controller: "UsersController", action: "index", model: "User" },
        { controller: "UsersController", action: "index", model: "User" },
        { controller: "UsersController", action: "show", model: "User" }
      ]

      result = parser.send(:aggregate_relationships, relationships)

      expect(result).to contain_exactly(
        { controller: "UsersController", model: "User", actions: %w[index show] }
      )
    end

    it "sorts actions alphabetically" do
      relationships = [
        { controller: "UsersController", action: "update", model: "User" },
        { controller: "UsersController", action: "create", model: "User" },
        { controller: "UsersController", action: "show", model: "User" },
        { controller: "UsersController", action: "index", model: "User" }
      ]

      result = parser.send(:aggregate_relationships, relationships)

      expect(result.first[:actions]).to eq(%w[create index show update])
    end
  end

  describe "#excluded?" do
    let(:mock_controller) { double("Controller", name: "UsersController") }

    context "with global config exclusions" do
      before do
        allow(parser.config).to receive(:exclude_controllers).and_return(["AdminController"])
      end

      it "excludes controllers in global config" do
        admin_controller = double("Controller", name: "AdminController")
        expect(parser.send(:excluded?, admin_controller)).to be true
      end

      it "does not exclude other controllers" do
        expect(parser.send(:excluded?, mock_controller)).to be false
      end
    end

    context "with command-line exclude option" do
      let(:parser) { described_class.new(exclude: ["TestController"]) }

      it "excludes controllers in exclude option" do
        test_controller = double("Controller", name: "TestController")
        expect(parser.send(:excluded?, test_controller)).to be true
      end

      it "does not exclude other controllers" do
        expect(parser.send(:excluded?, mock_controller)).to be false
      end
    end

    context "with command-line specify option" do
      let(:parser) { described_class.new(specify: ["UsersController", "PostsController"]) }

      it "includes controllers in specify option" do
        expect(parser.send(:excluded?, mock_controller)).to be false
      end

      it "excludes controllers not in specify option" do
        other_controller = double("Controller", name: "AdminController")
        expect(parser.send(:excluded?, other_controller)).to be true
      end
    end

    context "with anonymous controller" do
      let(:anonymous_controller) { double("Controller", name: nil) }

      it "excludes anonymous controllers" do
        expect(parser.send(:excluded?, anonymous_controller)).to be true
      end
    end
  end
end
