class ResourceDescription < ApplicationRecord
  belongs_to :resourceable, polymorphic: true
  belongs_to :image

  validates :title, :description, :url, presence: true

  delegate :url, to: :image, prefix: true, allow_nil: true
  delegate :byte_size, to: :image, allow_nil: true

  def image_url=(url)
    self.image ||= build_image
    image.url = url
  end

  def byte_size=(size)
    self.image ||= build_image
    image.byte_size = size
  end
end
