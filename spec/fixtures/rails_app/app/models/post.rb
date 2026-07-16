# frozen_string_literal: true

class Post < ApplicationRecord
  belongs_to :user, inverse_of: :posts

  def publish!
    update!(published: true)
  end
end
