module Types
  class TweetType < Types::BaseObject
    graphql_name "Tweet"
    field :uuid, ID, null: false
    field :resources, Types::ResourceDescriptionType, null: false

  end
end
