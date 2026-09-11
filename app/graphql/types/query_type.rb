# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    field :node, Types::NodeType, null: true, description: "Fetches an object given its ID." do
      argument :id, ID, required: true, description: "ID of the object."
    end

    def node(id:)
      context.schema.object_from_id(id, context)
    end

    field :nodes, [ Types::NodeType, null: true ], null: true, description: "Fetches a list of objects given a list of IDs." do
      argument :ids, [ ID ], required: true, description: "IDs of the objects."
    end

    def nodes(ids:)
      ids.map { |id| context.schema.object_from_id(id, context) }
    end

    # Add root-level fields here.
    # They will be entry points for queries on your schema.

    # TODO: remove me
    # field :test_field, String, null: false,
    #   description: "An example field added by the generator"
    # def test_field
    #   "Hello World!"
    # end
    field :tweets, [ Types::TweetType ], null: false, extras: [ :lookahead ]

    def tweets(lookahead:)
      preloads = preloads_for(lookahead)
      return Tweet.all if preloads.empty?

      Tweet.includes(*preloads)
    end

    private

    # Preload only what the query actually selects. Preloading unconditionally
    # would cost a client asking for `tweets { uuid message }` five extra
    # queries for comments, resources and images it never requested.
    def preloads_for(lookahead)
      preloads = []
      preloads << { resource_descriptions: :image } if lookahead.selects?(:resources)

      if lookahead.selects?(:comments)
        comments = lookahead.selection(:comments)
        preloads << if comments.selects?(:resources)
          { comments: { resource_descriptions: :image } }
        else
          :comments
        end
      end

      preloads
    end
  end
end
