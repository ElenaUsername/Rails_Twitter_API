module Types
  class TweetType < Types::BaseObject
    graphql_name "Tweet"

    field :uuid, ID, null: false
    field :message, String, null: false
    field :resources, [ Types::ResourceDescriptionType ], null: false
    field :comments, [ Types::CommentType ], null: false
  end
end
