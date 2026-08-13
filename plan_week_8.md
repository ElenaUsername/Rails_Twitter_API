# Week 8 — Comments with Open Graph resources

## Context

`week_8_requirements.md` asks for two additions to the existing GraphQL API:

1. A `commentCreate` mutation taking `tweetUuid` + `content`. The comment's content is
   scanned for URLs, Open Graph metadata is extracted from them and stored against the
   comment. Commenting on a `tweetUuid` that does not exist must return a **GraphQL error**,
   not a comment with a null field.
2. The existing `tweets` query must additionally expose each tweet's `comments`, with their
   `resources` fully nested.

The requirements call out two things explicitly, and both shape this plan:

- **Reuse, don't duplicate.** URL scanning and Open Graph extraction already exist for
  tweets. The interesting part of the exercise is making that code serve comments too,
  rather than writing a second copy.
- **Watch your queries.** `tweets` now loads comments and their resources. Measured on the
  target schema with 3 tweets × 2 comments × 1 resource each: **22 queries** with no eager
  loading, **6** with it.

Intended outcome: one `Comment` model, one `OpenGraphExtractionJob` serving both Tweet and
Comment, one `ResourceDescription` table serving both, and a `tweets` query whose query count
does not grow with the number of tweets or comments.

## Baseline

- Branch `week_eight` already exists off `main` and matches the `week_<number>` convention —
  no new branch needed.
- `bundle exec rspec` → **27 examples, 0 failures**. Clean green baseline, no pending specs.
- `bin/rubocop` config is pure `rubocop-rails-omakase`, no local overrides, no todo file.
- No new gems. `graphql-batch`, `factory_bot`, `vcr`, `bullet`, `prosopite` are all absent and
  stay absent (CLAUDE.md forbids Gemfile changes without permission).

## Key existing code to reuse

| Thing | Path | Reused how |
|---|---|---|
| URL scan + OG fetch/parse | `app/jobs/open_graph_extraction_job.rb` | Made record-agnostic; **not** copied |
| `ResourceDescription` + virtual `image_url=` / `byte_size=` writers | `app/models/resource_description.rb` | Made polymorphic; writers untouched |
| `Image` model | `app/models/image.rb` | Untouched |
| `ResourceDescriptionType`, `TweetImageType` (`graphql_name "Image"`) | `app/graphql/types/` | Reused verbatim by `CommentType` |
| `Mutations::TweetCreate` shape | `app/graphql/mutations/tweet_create.rb` | Template for `CommentCreate` |
| Tweet uuid/message/resources behaviour | `app/models/tweet.rb` | Extracted into a concern, shared with `Comment` |
| `stub_page(url, og: {})` helper | `spec/jobs/open_graph_extraction_job_spec.rb` | Reused for the Comment context |
| Request-spec idiom (`post '/graphql', as: :json`, `expect(json['errors']).to be_nil`) | `spec/graphql/**` | Followed for all new specs |

## Design decisions (confirmed)

- **Polymorphic `resourceable`** on `resource_descriptions`, replacing `belongs_to :tweet`.
  One table, one job, no `comment_resource_descriptions`. Cost: the
  `resource_descriptions → tweets` foreign key goes away (you cannot FK a polymorphic column).
- **Shared `ScannableContent` concern** for the behaviour Tweet and Comment have in common.
- **`perform(record)`** on the job, relying on ActiveJob GlobalID serialization, rather than
  `perform(class_name, id)` + `constantize`.
- **`GraphQL::ExecutionError`** for the missing tweet, not `ActiveRecord::RecordNotFound`
  (verified: `RecordNotFound` is in Rails' `rescue_responses`, so `ShowExceptions` renders a
  **404 HTML page** — `JSON.parse(response.body)` would blow up and there would be no
  `errors` array at all).
- **`includes` in the resolver**, not a `GraphQL::Dataloader::Source`. Both measure at 6
  queries; `includes` is 4 lines against a new directory + class + three type overrides, and
  CLAUDE.md forbids adding abstractions on my own initiative. `use GraphQL::Dataloader` stays
  where it is — inert and harmless.
- **No `Types::CommentCreateInputType`.** `RelayClassicMutation` auto-generates
  `input CommentCreateInput { tweetUuid: ID!, content: String! }`, exactly matching the
  required SDL. The existing `Types::TweetCreateInputType` is unwired dead code and will not
  be mirrored.
- `CommentType.resources` follows the existing `TweetType.resources` declaration
  (`[Types::ResourceDescriptionType], null: false` → `[ResourceDescription!]!`). The
  requirements write `[ResourceDescription]!`; consistency with the existing type wins, and
  the inner values are never null in practice.

---

## Implementation steps

Red/green pairs, in order. Each numbered step ends with `bin/rubocop` clean and a commit.
Steps marked **(refactor)** have no "Prove" half — their safety net is the existing 27 specs
staying green.

### 0. Paperwork (setup)

Write `plan_week_8.md` at the repo root with this plan verbatim (the user asked for it), and
open `PROMPTS.md` with `## Entry 1` for the planning prompt. `PROMPTS.md` currently exists but
is 0 bytes, so the first entry is Entry 1.

Commit: `Add week 8 implementation plan and first prompt log entry`

### 1. Make resource_descriptions polymorphic **(refactor)**

`db/migrate/<ts>_make_resource_descriptions_polymorphic.rb` — explicit `up`/`down`, **not**
`change`. A reversible `change` was tested and its rollback fails: the inverse
`add_reference :tweet, null: false` runs *before* the backfill, and adding a NOT NULL column
to a non-empty sqlite table raises `ActiveRecord::NotNullViolation`.

```ruby
def up
  add_reference :resource_descriptions, :resourceable, polymorphic: true
  execute <<~SQL.squish
    UPDATE resource_descriptions
    SET resourceable_type = 'Tweet', resourceable_id = tweet_id
  SQL
  change_column_null :resource_descriptions, :resourceable_type, false
  change_column_null :resource_descriptions, :resourceable_id, false
  remove_reference :resource_descriptions, :tweet, foreign_key: true
end

def down
  add_reference :resource_descriptions, :tweet, foreign_key: true
  execute "DELETE FROM resource_descriptions WHERE resourceable_type != 'Tweet'"
  execute "UPDATE resource_descriptions SET tweet_id = resourceable_id"
  change_column_null :resource_descriptions, :tweet_id, false
  remove_reference :resource_descriptions, :resourceable, polymorphic: true
end
```

Use `add_reference ..., polymorphic: true` rather than two `add_column`s plus a hand-written
`add_index`: it creates the columns nullable (required for the backfill) and auto-names the
composite index `index_resource_descriptions_on_resourceable`. A hand-written index name is
68 chars against a 62-char limit, so Rails would silently substitute a hashed name into
`schema.rb`.

Then:
- `app/models/resource_description.rb`: `belongs_to :tweet` → `belongs_to :resourceable, polymorphic: true`
- `app/models/tweet.rb`: `has_many :resource_descriptions, as: :resourceable, dependent: :destroy`

Migrate up, down, up to prove reversibility. `bundle exec rspec` must still be 27/0 —
`spec/model/tweet_spec.rb` and `spec/graphql/queries/tweets_spec.rb` both go through
`tweet.resource_descriptions.create!`, which behaves identically through `as: :resourceable`.

Expected `db/schema.rb` diff: `resourceable_type`/`resourceable_id` (both `null: false`) and
the new index appear, `tweet_id` and `add_foreign_key "resource_descriptions", "tweets"`
disappear.

Commit: `Make resource descriptions polymorphic`

### 2. Extract the ScannableContent concern **(refactor)**

`app/models/concerns/scannable_content.rb`:

```ruby
module ScannableContent
  extend ActiveSupport::Concern

  included do
    validates :content, presence: true
    has_many :resource_descriptions, as: :resourceable, dependent: :destroy
    alias_attribute :message, :content
    before_create :generate_uuid
  end

  def resources
    resource_descriptions
  end

  private

  def generate_uuid
    self.uuid = SecureRandom.uuid
  end
end
```

`app/models/tweet.rb` collapses to `include ScannableContent`. Still 27/0.

Commit: `Extract ScannableContent concern from Tweet`

### 3. Comment model

**Prove** — `spec/model/comment_spec.rb` (note: existing dir is `spec/model`, singular):
a comment created through `tweet.comments.create!` gets a present 36-char `uuid`, `message`
returns `content`, blank content is invalid, and `comment.resource_descriptions.create!` with
`image_url:`/`byte_size:` works. Red with `NameError: uninitialized constant Comment`.

**Implement** — `db/migrate/<ts>_create_comments.rb` (plain reversible `change`, mirroring
`CreateTweets` style: `t.string :uuid`, `t.text :content`,
`t.references :tweet, null: false, foreign_key: true`, `t.timestamps`) and:

```ruby
class Comment < ApplicationRecord
  include ScannableContent

  belongs_to :tweet
end
```

Plus `has_many :comments, dependent: :destroy` on `Tweet`.

Commit: `Add Comment model`

### 4. Make the extraction job record-agnostic

**Prove** — in `spec/jobs/open_graph_extraction_job_spec.rb`, flip all 8 call sites
(`described_class.perform_now(tweet.id)` → `perform_now(tweet)`; lines 26, 51, 60, 73, 88,
105, 118, 135) and add a new context proving reuse against a Comment:

```ruby
context 'when the record is a Comment' do
  let(:tweet) { Tweet.create!(content: 'parent tweet') }
  let(:comment) { tweet.comments.create!(content: 'nice ladder https://example.com/article') }

  before do
    stub_page('https://example.com/article', og: {
      'og:title' => 'Cool Article',
      'og:description' => 'A description',
      'og:url' => 'https://example.com/article'
    })
  end

  it 'extracts resources against the comment' do
    expect { described_class.perform_now(comment) }
      .to change(comment.resource_descriptions, :count).by(1)

    expect(comment.resource_descriptions.last.title).to eq('Cool Article')
  end
end
```

Red on `Integer#content` / `NoMethodError`.

**Implement** — in `app/jobs/open_graph_extraction_job.rb`, `perform(tweet_id)` → `perform(record)`,
delete the `Tweet.find(tweet_id)` line, and rename the two body references to `record.content`
and `record.resource_descriptions.create!`. **Everything below `private` is unchanged** — the
Faraday/Nokogiri/`og:` parsing, the `next unless` guard, the `Faraday.head` byte-size lookup
and both rescues stay byte-identical. No Comment branch, no second job class.

Also update the one existing call site:
`app/graphql/mutations/tweet_create.rb` → `OpenGraphExtractionJob.perform_later(tweet)`.

Commit: `Extract Open Graph metadata for any record with content`

### 5. Comment GraphQL type

**Prove** — `spec/graphql/types/comment_type_spec.rb`, following the shape of the five
existing type specs: `graphql_name == "Comment"`, `fields.keys` `contain_exactly("uuid",
"message", "resources")`, all three non-null.

**Implement** — `app/graphql/types/comment_type.rb`, mirroring `TweetType` and reusing
`Types::ResourceDescriptionType`.

Commit: `Add Comment GraphQL type`

### 6. commentCreate mutation — happy path

**Prove** — `spec/graphql/mutations/comment_create_spec.rb`, `type: :request`, posting the
exact mutation from the requirements with a real `tweetUuid`: `Comment` count changes by 1,
`json['errors']` nil, `data.commentCreate.comment.uuid` present, and the extraction job is
enqueued for that comment. Also update
`spec/graphql/types/mutation_type_spec.rb` — its `contain_exactly("tweetCreate")` is an exact
match assertion and must become `contain_exactly("tweetCreate", "commentCreate")`; it goes red
on its own, which is the signal that the mutation is registered.

For the enqueue assertion, prefer rspec-rails' `have_enqueued_job(OpenGraphExtractionJob).with(comment)`
— the matcher round-trips both sides through `ActiveJob::Arguments.serialize/deserialize`, so
a GlobalID argument compares correctly. If the matcher turns out not to be available in a
`type: :request` group, fall back to inspecting
`ActiveJob::Base.queue_adapter.enqueued_jobs` rather than stubbing `perform_later`.

**Implement** — `app/graphql/mutations/comment_create.rb`:

```ruby
module Mutations
  class CommentCreate < BaseMutation
    argument :tweet_uuid, ID, required: true
    argument :content, String, required: true

    field :comment, Types::CommentType, null: false

    def resolve(tweet_uuid:, content:)
      tweet = Tweet.find_by(uuid: tweet_uuid)
      raise GraphQL::ExecutionError, "Tweet not found: #{tweet_uuid}" if tweet.nil?

      comment = tweet.comments.create!(content: content)
      OpenGraphExtractionJob.perform_later(comment)
      { comment: comment }
    end
  end
end
```

plus `field :comment_create, mutation: Mutations::CommentCreate` on `Types::MutationType`.

Commit: `Add commentCreate mutation`

### 7. commentCreate — unknown tweetUuid returns a GraphQL error

**Prove** — a second context in the same request spec. Verified actual response for this
resolver: HTTP **200**, `{"errors":[{"message":"Tweet not found: does-not-exist","path":["commentCreate"]}],"data":{"commentCreate":null}}`.

```ruby
expect { post '/graphql', ... }.not_to change(Comment, :count)
expect(response).to have_http_status(200)

json = JSON.parse(response.body)
expect(json['errors'].length).to eq(1)
expect(json['errors'].first['message']).to eq('Tweet not found: does-not-exist')
expect(json['errors'].first['path']).to eq([ 'commentCreate' ])
expect(json['data']).to eq('commentCreate' => nil)
expect(json['errors'].map { |e| e['message'] })
  .not_to include(a_string_matching(/Cannot return null for non-nullable field/))
```

The last assertion is the one that actually pins the requirement. The first three would also
pass if the resolver returned `{ comment: nil }` — which produces
`"Cannot return null for non-nullable field CommentCreatePayload.comment"` and is precisely
the "comment with a null field" outcome the requirement forbids. Add a second example
asserting no job is enqueued.

This step is likely already green from step 6's implementation. If so, say so plainly rather
than pretending it was red — and keep the specs, since they're what document the requirement.

Commit: `Cover unknown tweetUuid on commentCreate` (or fold into step 6 if step 7 needs no
production change)

### 8. Expose comments on the tweets query

**Prove** — extend `spec/graphql/queries/tweets_spec.rb`'s query with the `comments { uuid
message resources { ... image { url byteSize } } }` block from the requirements and add a
context asserting a tweet returns its comment with the comment's own resources. Update
`spec/graphql/types/tweet_type_spec.rb`'s `contain_exactly` to include `"comments"` and assert
it non-null — again red on its own.

**Implement** — `field :comments, [ Types::CommentType ], null: false` on `Types::TweetType`
(resolves implicitly through the `has_many` added in step 3).

Commit: `Expose comments on the Tweet type`

### 9. Fix the N+1 on the tweets query

**Prove** — `spec/graphql/queries/tweets_query_count_spec.rb`: seed 3 tweets × 1 resource ×
2 comments × 1 resource each, run the full nested query, count `sql.active_record`
notifications, expect **6**. Red at **22**.

```ruby
def count_queries
  queries = []
  callback = lambda do |*, payload|
    next if payload[:cached]
    next if %w[SCHEMA TRANSACTION].include?(payload[:name])

    queries << payload[:sql]
  end
  ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { yield }
  queries
end
```

Two details that were checked and that naive versions get wrong: cached queries keep their
real `payload[:name]` in Rails 8.1 and are only identifiable via `payload[:cached]`, and
`"SCHEMA"`/`"TRANSACTION"` are real names worth excluding. Keep the ignore list inline in the
method (not a constant in the describe block) to stay clear of
`Lint/ConstantDefinitionInBlock`. Give the `eq(6)` a custom failure message that dumps the
SQL — a bare count failure tells you nothing about *which* association leaked.

**Implement** — `app/graphql/types/query_type.rb`:

```ruby
def tweets
  Tweet.includes(
    { resource_descriptions: :image },
    comments: { resource_descriptions: :image }
  )
end
```

**Critical:** it must be `:resource_descriptions`, not `:resources`. `resources` is a plain
method wrapping the association, so `includes(:resources)` raises
`ActiveRecord::AssociationNotFoundError`. The GraphQL `resources` field still resolves through
`object.resources` → the already-loaded `CollectionProxy`, firing no extra query.

The 6 queries are: tweets, tweet resource_descriptions, their images, comments, comment
resource_descriptions, their images. Rails does not merge the two `images` loads — 6, not 5.

Commit: `Eager load comments and resources in the tweets query`

---

## Verification

1. `bundle exec rspec` — expect the 27 baseline examples plus roughly 12 new ones, 0 failures.
2. `bin/rubocop` — clean (it is run before every commit, not once at the end).
3. `bin/rails db:migrate` then `bin/rails db:rollback STEP=2` then `bin/rails db:migrate` —
   proves both migrations reverse cleanly on sqlite.
4. Drive the real app (delegate to the `run` skill): `bin/rails server`, plus `bin/jobs` in a
   second terminal so solid_queue actually processes the extraction job in development.
   Then, against `/graphiql` or via `curl` to `POST /graphql`:
   - `tweetCreate` with a URL-bearing message → note the returned `uuid`.
   - `commentCreate` with that `tweetUuid` and a message containing a real URL → returns a
     comment `uuid`.
   - `commentCreate` with `"tweetUuid": "1231-1231-1231-1231"` → HTTP 200 with an `errors`
     array and `data.commentCreate == null`.
   - the full `tweets` query from the requirements → tweet and comment resources both
     populated with real title/description/url/image.
   Record the actual command output for each, not the hoped-for output.
5. Tail the development log during step 4 and confirm the `tweets` query fires 6 SELECTs.
   `config/application.rb` already tags SQL with `current_graphql_field`, so the log shows
   which field fired each query.
6. Append a `PROMPTS.md` entry per exchange throughout, and draft the closing `## Reflection`
   section at the end — flagged as a draft for you to finalize.

## Out of scope

Deliberately not doing, though each was noticed:

- A unique index or uniqueness validation on `tweets.uuid` / `comments.uuid` (absent today).
- Uncommenting `discard_on ActiveJob::DeserializationError` in `app/jobs/application_job.rb`.
  Worth knowing: with GlobalID args, a record destroyed between enqueue and pickup raises
  `ActiveJob::DeserializationError` before `perform` runs, so it cannot be handled inside the
  job. Say the word and it becomes a one-line step.
- Deleting the dead `Types::TweetCreateInputType` and its spec.
- Ordering of `comments` (not specified in the requirements).
- `config/ci.rb` still running `bin/rails test` (Minitest) while GitHub Actions runs
  `bundle exec rspec` — pre-existing drift, unrelated to this feature.
- Any Gemfile change.
