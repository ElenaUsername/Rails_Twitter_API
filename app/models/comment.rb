class Comment < ApplicationRecord
  include ScannableContent

  belongs_to :tweet
end
