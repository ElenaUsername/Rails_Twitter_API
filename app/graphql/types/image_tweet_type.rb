module Types
  class ImageTweetType < Types::BaseObject
    graphql_name "Image"

    field :url, String, null: false
    field :byte_size, Integer, null: false
  end
end