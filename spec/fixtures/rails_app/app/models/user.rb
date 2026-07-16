# frozen_string_literal: true

class User < ApplicationRecord
  has_many :posts, inverse_of: :user

  def display_name
    email
  end
end
