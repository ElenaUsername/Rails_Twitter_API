module Types
  class MutationType < Types::BaseObject
    field :tweet_create, mutation: Mutations::TweetCreate
  end
end
