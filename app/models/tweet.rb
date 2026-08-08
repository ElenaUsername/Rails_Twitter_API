class Tweet < ApplicationRecord
  validates :content, presence: true

  has_many :resource_descriptions, dependent: :destroy

  alias_attribute :message, :content

  def resources
    resource_descriptions
  end

  before_create :generate_uuid

  private

  def generate_uuid
    self.uuid = SecureRandom.uuid
  end
end
