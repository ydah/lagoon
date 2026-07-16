# frozen_string_literal: true

class UsersController < ApplicationController
  before_action :set_user, only: :show

  def index
    @users = User.all
  end

  def show
    load_posts
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def load_posts
    @posts = @user.posts
  end
end
