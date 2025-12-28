# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require_relative "../../../lib/lagoon/analyzer/ast_model_reference_analyzer"

RSpec.describe Lagoon::Analyzer::AstModelReferenceAnalyzer do
  subject(:analyzer) { described_class.new }

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

        result = analyzer.analyze(temp_file.path, ["show"])
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

        result = analyzer.analyze(temp_file.path, ["show"])
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

        result = analyzer.analyze(temp_file.path, ["show", "index"])
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

        result = analyzer.analyze(temp_file.path, ["show"])
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

        result = analyzer.analyze(temp_file.path, ["show"])
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

        result = analyzer.analyze(temp_file.path, ["show"])
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

        result = analyzer.analyze(temp_file.path, ["show"])
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

        result = analyzer.analyze(temp_file.path, ["show"])
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

        result = analyzer.analyze(temp_file.path, ["show"])
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

        result = analyzer.analyze(temp_file.path, ["show"])
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

        result = analyzer.analyze(temp_file.path, ["show"])
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

        result = analyzer.analyze(temp_file.path, ["index"])
        expect(result["index"].to_a).to include("User")
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

        result = analyzer.analyze(temp_file.path, ["new"])
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

        result = analyzer.analyze(temp_file.path, ["show", "index"])
        expect(result).to be_empty
      end
    end
  end
end
