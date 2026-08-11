class Tweet < ApplicationRecord
  include ScannableContent

  has_many :comments, dependent: :destroy
end
