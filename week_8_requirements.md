Create Comment Mutation to the existing project. 
The API will receive a tweet's uuid and a text message.
Scans the comment's content for URLs, same as tweets do.
Extracts Open Graph Metadata from those URLs and saves it against the comment for later querying.
Commenting against a tweetUuid that doesn't exist returns a GraphQL error, not a comment with a null field.
type CommentCreateInput {
    tweetUuid: ID!
    content: String!
}

mutation($input: CommentCreateInput!) {
    commentCreate(input: $input) {
        comment {
            uuid
        }
    }
}
Example variables:

{
  "input": {
    "tweetUuid": "1231-1231-1231-1231",
    "content": "This is exactly the ladder I needed: https://12ft.io/"
  }
}
Returns:

{
  "comment": {
    "uuid": "9911-9911-9911-9911"
  }
}
List Tweets Query
Update the existing tweets query so each tweet also exposes its comments, resources and all.

type Comment {
    uuid: ID!
    message: String!
    resources: [ResourceDescription]!
}

type Tweet {
    uuid: ID!
    message: String!
    resources: [ResourceDescription]!
    comments: [Comment]!
}

query {
    tweets {
        uuid
        message
        resources {
            title
            description
            url
            image {
                url
            }
        }
        comments {
            uuid
            message
            resources {
                title
                description
                url
                image {
                    url
                }
            }
        }
    }
}
Example Return:

{
  "tweets": [
    {
      "uuid": "1231-1231-1231-1231",
      "message": "Best thing I found in a while: https://12ft.io/",
      "resources": [
        {
          "title": "12ft – Hop any paywall",
          "description": "Show me a 10ft paywall, I’ll show you a 12ft ladder",
          "url": "https://12ft.io/",
          "image": {
            "url": "https://12ft.io/og-banner.png"
          }
        }
      ],
      "comments": [
        {
          "uuid": "9911-9911-9911-9911",
          "message": "This is exactly the ladder I needed: https://12ft.io/",
          "resources": [
            {
              "title": "12ft – Hop any paywall",
              "description": "Show me a 10ft paywall, I’ll show you a 12ft ladder",
              "url": "https://12ft.io/",
              "image": {
                "url": "https://12ft.io/og-banner.png"
              }
            }
          ]
        }
      ]
    }
  ]
}
General Considerations
Reuse, don't duplicate. You already scan URLs and extract Open Graph metadata for tweets. 

Watch your queries. tweets now loads comments and their resources too. Have a look at how many queries that fires for a handful of tweets, each with a handful of comments.