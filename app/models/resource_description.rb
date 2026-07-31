class ResourceDescription < ApplicationRecord
  belongs_to :tweet

  validates :title, :description, :url, presence: true

  def image
    { url: image_url, byte_size: byte_size }
  end
end
