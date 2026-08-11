# Prompts

## Entry 1

> /plan I need you to analyse the existing project and to plan how to add the new feature that
> is described in the week_8_requirements.md. Plan step by step what should be done and take in
> consideration to reuse the existing code. When planing make sure to follow the rules from
> CLAUDE.md and from feature-development.md. După ce planul e gata, salvează-l integral în
> plan_week_8.md

**Response:** A 10-step red/green plan saved to `plan_week_8.md`. Key decisions, each verified
empirically against the installed gems rather than assumed: polymorphic `resourceable` on
`resource_descriptions` via an explicit `up`/`down` migration (a reversible `change` fails on
rollback with `NotNullViolation`); a shared `ScannableContent` concern for Tweet and Comment;
`OpenGraphExtractionJob#perform(record)` using GlobalID so the single job serves both;
`GraphQL::ExecutionError` for an unknown `tweetUuid` (`ActiveRecord::RecordNotFound` would
render a 404 HTML page, not a GraphQL error); and `Tweet.includes(...)` in the `tweets`
resolver, which drops the nested query from 22 to 6 — the same count a `GraphQL::Dataloader`
Source would achieve, for far less machinery.

**Verdict:** accepted

## Entry 2

> [Plan approved via plan mode, authorising implementation of the 10 steps in
> `plan_week_8.md`.]

**Response:** Implemented all 10 steps as separate red/green commits, each one RuboCop-clean
before committing. The suite went from 27 to 44 examples, 0 failures. Every red was confirmed
genuine and for the intended reason before any production code was written — most usefully the
N+1 spec, which failed at exactly the predicted 22 queries and printed the offending SQL tagged
by `current_graphql_field`. Two steps of the plan (the happy path and the unknown-`tweetUuid`
path of `commentCreate`) turned out to need a single production change between them, so they
were committed together rather than pretending step 7 had its own red.

Verified in the running app against live URLs, not just in specs: `commentCreate` with a bogus
uuid returns HTTP 200 with `{"errors":[...],"data":{"commentCreate":null}}`; a tweet and a
comment each got real Open Graph data (ruby-lang.org and github.com/rails/rails) through the
same job; and the `tweets` query logged `6 queries` at both 1 tweet and 4 tweets / 7 comments,
confirming the count is constant rather than merely small.

Found along the way, pre-existing and left alone: `solid_queue` is the development queue
adapter but the `solid_queue_*` tables were never created in the development database, so
`perform_later` raises there. Open Graph extraction has therefore never worked in this
project's development environment, for tweets either.

**Verdict:** accepted

## Entry 3

> fix the solid_queue tables so jobs run in development

**Response:** Gave development its own queue database, mirroring the production layout: a
`queue` entry under `development:` in `config/database.yml` plus
`config.solid_queue.connects_to` in `config/environments/development.rb`, then
`bin/rails db:prepare` to load `db/queue_schema.rb` into it. Two config lines changed, no
migration and no Gemfile change.

The alternative — loading the queue schema into the primary development database — was
rejected because the next `bin/rails db:migrate` would have dumped all eleven `solid_queue_*`
tables into the tracked `db/schema.rb`. Confirmed after the fix that `db/schema.rb` and
`db/queue_schema.rb` are both unchanged.

Verified end to end with `bin/rails server` and `bin/jobs` running: `tweetCreate` and
`commentCreate` over HTTP, both jobs claimed by the worker within two seconds, real Open Graph
metadata stored for the tweet and the comment, `2 jobs / 2 finished / 0 failed` in the queue
database. This one had no RSpec red half — the specs run under the `:test` queue adapter and
never touch solid_queue, so the failure only existed in the development environment and the
proof had to be the running app.

**Verdict:** accepted

## Entry 4

> push all the modifications on existing week_eight

**Response:** Pushed `3ae1ce2..a2fa6cf` to `origin/week_eight` — 13 commits, a clean
fast-forward with no force and no rewritten history, since the commits were curated before the
first push. Checked beforehand that the diff contained no `.env`, `.key`, credentials or `.pem`
files and that `storage/*.sqlite3` is gitignored, so neither database went up. No pull request
opened.

**Verdict:** accepted

## Entry 5

> complete this two things that are still open and commit as well

**Response:** Closed both. `config/ci.rb` ran `bin/rails test` while the project has no `test/`
directory and no Minitest tests — so `bin/ci` reported success having run no tests at all; it
now prepares the test database and runs `bundle exec rspec`, matching the GitHub workflow.
Verified `db:test:prepare` still works against the multi-database development config.

The reflection is finalized, and both rules it proposed were added to `CLAUDE.md` as
*Definition of done* and *Refactoring in service of reuse*. One clarification was needed first:
the initial answer selected both rules and "leave CLAUDE.md alone" together, which cancel out,
so the choice was put again rather than guessed at.

**Verdict:** accepted

## Reflection

Reviewed and accepted. Both rules proposed below were added to `CLAUDE.md`.

**Which prompt did the most work.** Entry 1, decisively — and not because of the plan text
itself but because it was answered with codebase exploration and empirical probing rather than
recall. Four claims that would have been plausible guesses were tested against the installed
gems first, and three of them were wrong in ways that would have cost real debugging time:
a reversible `change` migration looks correct and fails only on rollback; `ActiveRecord::RecordNotFound`
looks like the idiomatic way to signal a missing record and actually yields a 404 HTML page with
no `errors` array at all; and `includes(:resources)` looks right but raises
`AssociationNotFoundError` because `resources` is a plain method, not an association. The
implementation prompt then had almost nothing left to decide.

**Where manual correction was needed.** Very little, but three judgement calls were escalated
rather than assumed, and all three were the user's to make: whether to extract a shared concern
or duplicate the six lines in `Comment`; whether to lock the query count with an exact
assertion or a lenient bound; and whether to mirror the existing dead `TweetCreateInputType`.
The last is the interesting one — the "consistent with the codebase" answer and the "don't add
dead code" answer point in opposite directions, and that is not a call an agent should quietly
make on someone's coursework.

**What rules were added, and why.** Two, both now in `CLAUDE.md`.

*Definition of done* — a green suite is not evidence that a feature works; drive it in the
running app and record the actual output. This is the rule the session actually earned. The
feature was at `44 examples, 0 failures` while `perform_later` was raising in development, and
no reachable RSpec example could have caught it, because the `:test` queue adapter never runs a
job. Without this rule the honest report is "all tests pass", which was true and misleading at
the same time.

*Refactoring in service of reuse* — the existing rules say to reuse rather than duplicate, but
said nothing about what to do when reuse requires *modifying* existing working code. Making
`resource_descriptions` polymorphic and rewriting `Tweet` touched three files that had nothing
wrong with them. That was the right move, and it was cheap only because 27 green specs made it
safe, so the rule records that precondition and the separate-commit habit that goes with it.

**What was nearly merged despite being wrong.** Two things.

First, `spec/graphql/types/mutation_type_spec.rb` and `tweet_type_spec.rb` assert `fields.keys`
with `contain_exactly`, so both broke the moment `commentCreate` and `comments` were
registered. Those failures were treated as the red half of their steps — but the same
failure would look like collateral damage to be silenced, and updating an exact-match
assertion to match whatever the code now does is exactly how a type spec stops testing
anything. Worth watching for in review.

Second, and more seriously: the whole feature could have been declared done on `44 examples,
0 failures` while `perform_later` was in fact raising in the development environment. The
specs pass because the test queue adapter never runs a job. Only driving the real app surfaced
the missing `solid_queue` tables. A green suite said nothing about it, and no reachable test
would have — which is the strongest argument in this session for the rule that a feature is not
done until it has been driven in the running app. That gap was closed in Entry 3.
