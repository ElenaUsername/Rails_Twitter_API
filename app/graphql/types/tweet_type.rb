module Types
  class TweetType < Types::BaseObject
    graphql_name "Tweet"
    field :uuid, ID, null: false
  end
end
