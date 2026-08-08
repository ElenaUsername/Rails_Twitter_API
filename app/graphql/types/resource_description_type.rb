module Types
  class ResourceDescriptionType < Types::BaseObject
    graphql_name "ResourceDescription"

    field :title, String, null: false
    field :description, String, null: false
    field :url, String, null: false
    field :image, Types::TweetImageType, null: false
  end
end
