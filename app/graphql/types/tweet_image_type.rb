module Types
  class TweetImageType < Types::BaseObject
    graphql_name 'Image'

    field :url, String, null: false
    field :byte_size, Integer, null: false
  end
end
