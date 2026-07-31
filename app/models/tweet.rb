class Tweet < ApplicationRecord
  validates :content, presence: true

  before_create :generate_uuid

  private
  def generate_uuid
    self.uuid = SecureRandom.uuid
  end
end
