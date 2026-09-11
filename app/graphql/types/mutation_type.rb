module Types
  class MutationType < Types::BaseObject
    field :tweet_create, mutation: Mutations::TweetCreate
    field :comment_create, mutation: Mutations::CommentCreate
  end
end
