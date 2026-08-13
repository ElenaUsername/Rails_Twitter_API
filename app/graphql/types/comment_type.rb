module Types
  class CommentType < Types::BaseObject
    graphql_name "Comment"

    field :uuid, ID, null: false
    field :message, String, null: false
    field :resources, [ Types::ResourceDescriptionType ], null: false
  end
end
