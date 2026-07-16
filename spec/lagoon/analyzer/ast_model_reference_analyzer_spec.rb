# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require_relative "../../../lib/lagoon/analyzer/ast_model_reference_analyzer"

RSpec.describe Lagoon::Analyzer::AstModelReferenceAnalyzer do
  subject(:analyzer) { described_class.new }

  let(:analysis_options) do
    {
      model_names: %w[User Post Comment Profile Role Admin APIClient SSOUser CRMAccount Admin::User],
      associations: {
        "User" => { "posts" => "Post", "comments" => "Comment", "profile" => "Profile" },
        "Post" => { "comments" => "Comment" }
      },
      helper_models: { "current_user" => "User", "current_account" => "CRMAccount" }
    }
  end

  describe "#analyze" do
    let(:temp_file) { Tempfile.new(["controller", ".rb"]) }

    after { temp_file.unlink }

    context "with simple model references" do
      it "detects User.find" do
        temp_file.write(<<~RUBY)
          class UsersController
            def show
              @user = User.find(params[:id])
            end
          end
        RUBY
        temp_file.rewind

        result = analyzer.analyze(temp_file.path, ["show"], **analysis_options)
        expect(result["show"].to_a).to include("User")
      end

      it "detects multiple models in one action" do
        temp_file.write(<<~RUBY)
          class UsersController
            def show
              @user = User.find(params[:id])
              @posts = Post.where(user_id: @user.id)
              @role = Role.find_by(name: 'admin')
            end
          end
        RUBY
        temp_file.rewind

        result = analyzer.analyze(temp_file.path, ["show"], **analysis_options)
        expect(result["show"].to_a).to match_array(%w[User Post Role])
      end

      it "detects models only in specified actions" do
        temp_file.write(<<~RUBY)
          class UsersController
            def show
              @user = User.find(params[:id])
            end

            def index
              @posts = Post.all
            end

            def edit
              @role = Role.first
            end
          end
        RUBY
        temp_file.rewind

        result = analyzer.analyze(temp_file.path, ["show", "index"], **analysis_options)
        expect(result["show"].to_a).to include("User")
        expect(result["index"].to_a).to include("Post")
        expect(result.keys).not_to include("edit")
      end
    end

    context "with association references" do
      it "detects association method calls" do
        temp_file.write(<<~RUBY)
          class UsersController
            def show
              @user = User.find(params[:id])
              @posts = @user.posts
              @comments = @user.comments
            end
          end
        RUBY
        temp_file.rewind

        result = analyzer.analyze(temp_file.path, ["show"], **analysis_options)
        expect(result["show"].to_a).to include("User", "Post", "Comment")
      end

      it "handles singular associations" do
        temp_file.write(<<~RUBY)
          class UsersController
            def show
              @user = User.find(params[:id])
              @profile = @user.profile
            end
          end
        RUBY
        temp_file.rewind

        result = analyzer.analyze(temp_file.path, ["show"], **analysis_options)
        expect(result["show"].to_a).to include("User", "Profile")
      end
    end

    context "with helper method references" do
      it "detects current_user" do
        temp_file.write(<<~RUBY)
          class UsersController
            def show
              @posts = current_user.posts
            end
          end
        RUBY
        temp_file.rewind

        result = analyzer.analyze(temp_file.path, ["show"], **analysis_options)
        expect(result["show"].to_a).to include("User", "Post")
      end
    end

    context "with filters" do
      it "excludes non-model constants" do
        temp_file.write(<<~RUBY)
          class UsersController
            def show
              @time = DateTime.now
              @data = JSON.parse(params[:data])
              @hash = Hash.new
              @user = User.find(params[:id])
            end
          end
        RUBY
        temp_file.rewind

        result = analyzer.analyze(temp_file.path, ["show"], **analysis_options)
        expect(result["show"].to_a).to eq(["User"])
      end

      it "excludes Rails framework constants" do
        temp_file.write(<<~RUBY)
          class UsersController
            def show
              Rails.logger.info("test")
              ActiveRecord::Base.connection
              @user = User.find(params[:id])
            end
          end
        RUBY
        temp_file.rewind

        result = analyzer.analyze(temp_file.path, ["show"], **analysis_options)
        expect(result["show"].to_a).to eq(["User"])
      end

      it "excludes Application prefix constants" do
        temp_file.write(<<~RUBY)
          class UsersController
            def show
              ApplicationRecord.connection
              @user = User.find(params[:id])
            end
          end
        RUBY
        temp_file.rewind

        result = analyzer.analyze(temp_file.path, ["show"], **analysis_options)
        expect(result["show"].to_a).to eq(["User"])
      end

      it "excludes common controller variables" do
        temp_file.write(<<~RUBY)
          class UsersController
            def show
              params[:id]
              session[:user_id]
              request.headers
              response.body
              @user = User.find(params[:id])
            end
          end
        RUBY
        temp_file.rewind

        result = analyzer.analyze(temp_file.path, ["show"], **analysis_options)
        expect(result["show"].to_a).to eq(["User"])
      end
    end

    context "with complex code patterns" do
      it "detects models in conditionals" do
        temp_file.write(<<~RUBY)
          class UsersController
            def show
              if params[:admin]
                @user = Admin.find(params[:id])
              else
                @user = User.find(params[:id])
              end
            end
          end
        RUBY
        temp_file.rewind

        result = analyzer.analyze(temp_file.path, ["show"], **analysis_options)
        expect(result["show"].to_a).to match_array(%w[Admin User])
      end

      it "detects models in blocks" do
        temp_file.write(<<~RUBY)
          class UsersController
            def index
              @users = User.where(active: true).each do |user|
                user.posts.each do |post|
                  post.comments
                end
              end
            end
          end
        RUBY
        temp_file.rewind

        result = analyzer.analyze(temp_file.path, ["index"], **analysis_options)
        expect(result["index"].to_a).to include("User", "Post", "Comment")
      end
    end

    context "with empty actions" do
      it "returns empty set for action with no model references" do
        temp_file.write(<<~RUBY)
          class UsersController
            def new
              # No model references
            end
          end
        RUBY
        temp_file.rewind

        result = analyzer.analyze(temp_file.path, ["new"], **analysis_options)
        expect(result["new"].to_a).to be_empty
      end
    end

    context "with no matching actions" do
      it "returns empty hash when no actions match" do
        temp_file.write(<<~RUBY)
          class UsersController
            def private_method
              User.all
            end
          end
        RUBY
        temp_file.rewind

        result = analyzer.analyze(temp_file.path, ["show", "index"], **analysis_options)
        expect(result).to be_empty
      end
    end

    context "with model validation and data flow" do
      it "does not turn arbitrary model methods or service constants into models" do
        temp_file.write(<<~RUBY)
          class UsersController
            def update
              @user = User.find(params[:id])
              @user.save
              @user.errors
              @user.update(name: "new")
              @user.attributes
              PaymentService.call
              Money.new
              Policy.find
            end
          end
        RUBY
        temp_file.rewind

        result = analyzer.analyze(temp_file.path, ["update"], **analysis_options)

        expect(result["update"].to_a).to eq(["User"])
      end

      it "detects namespaced and acronym model constants, including standalone references" do
        temp_file.write(<<~RUBY)
          class UsersController
            def show
              Admin::User.find(params[:id])
              clients = APIClient
              authorize SSOUser
              CRMAccount.where(active: true)
            end
          end
        RUBY
        temp_file.rewind

        result = analyzer.analyze(temp_file.path, ["show"], **analysis_options)

        expect(result["show"].to_a).to match_array(%w[Admin::User APIClient SSOUser CRMAccount])
      end

      it "tracks local variables, block parameters, and full association chains" do
        temp_file.write(<<~RUBY)
          class UsersController
            def index
              user = User.first
              user.posts.each do |post|
                post.comments
              end
              @comments = user.posts.comments
            end
          end
        RUBY
        temp_file.rewind

        result = analyzer.analyze(temp_file.path, ["index"], **analysis_options)

        expect(result["index"].to_a).to match_array(%w[User Post Comment])
      end
    end

    context "with callbacks and helper methods" do
      it "follows before_action and argument-free private helper calls" do
        temp_file.write(<<~RUBY)
          class UsersController
            before_action :set_user, only: :show

            def show
              load_posts
            end

            private

            def set_user
              @user = User.find(params[:id])
            end

            def load_posts
              @user.posts
            end
          end
        RUBY
        temp_file.rewind

        result = analyzer.analyze(
          temp_file.path,
          ["show"],
          controller_names: ["UsersController"],
          **analysis_options
        )

        expect(result["show"].to_a).to match_array(%w[User Post])
      end

      it "uses a configurable helper-to-model mapping" do
        temp_file.write(<<~RUBY)
          class AccountsController
            def show
              current_account
            end
          end
        RUBY
        temp_file.rewind

        result = analyzer.analyze(temp_file.path, ["show"], **analysis_options)

        expect(result["show"].to_a).to eq(["CRMAccount"])
      end
    end

    context "with source scoping and errors" do
      it "only analyzes the requested controller class" do
        temp_file.write(<<~RUBY)
          class UsersController
            def index
              User.all
            end
          end

          class ReportsController
            def index
              Post.all
            end
          end
        RUBY
        temp_file.rewind

        result = analyzer.analyze(
          temp_file.path,
          ["index"],
          controller_names: ["UsersController"],
          **analysis_options
        )

        expect(result["index"].to_a).to eq(["User"])
      end

      it "combines reopened class definitions from multiple files" do
        second_file = Tempfile.new(["controller_extension", ".rb"])
        temp_file.write("class UsersController; def index; load_user; end; end")
        temp_file.rewind
        second_file.write("class UsersController; def load_user; User.first; end; end")
        second_file.rewind

        result = analyzer.analyze(
          [temp_file.path, second_file.path],
          ["index"],
          controller_names: ["UsersController"],
          **analysis_options
        )

        expect(result["index"].to_a).to eq(["User"])
      ensure
        second_file&.unlink
      end

      it "raises a dedicated parse error for invalid Ruby" do
        temp_file.write("class UsersController; def show(")
        temp_file.rewind

        expect do
          analyzer.analyze(temp_file.path, ["show"], **analysis_options)
        end.to raise_error(Lagoon::ParseError, /Syntax error/)
      end
    end
  end
end
