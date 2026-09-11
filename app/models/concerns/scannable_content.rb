module ScannableContent
  extend ActiveSupport::Concern

  included do
    validates :content, presence: true

    has_many :resource_descriptions, as: :resourceable, dependent: :destroy

    alias_attribute :message, :content

    before_create :generate_uuid
  end

  def resources
    resource_descriptions
  end

  private

  def generate_uuid
    self.uuid = SecureRandom.uuid
  end
end
