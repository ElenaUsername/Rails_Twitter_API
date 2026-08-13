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

## Entry 6

> scan_ruby job failed. The pr was created based on all the commits from branch

**Response:** Not brakeman — that reported zero warnings. `bundler-audit` failed on `json`
2.21.1, CVE-2026-71847, fixed in 2.21.2. Established first that this was not a regression from
the PR: `Gemfile` and `Gemfile.lock` are byte-identical to `main` across every commit on the
branch, and `json` is transitive (only rubocop constrains it, at `~> 2.3`). The advisory
database picked the CVE up on 2026-08-10, so `main` fails the same check.

`gh` was not installed at this point, so the job was reproduced locally rather than read from
the CI logs. Because `CLAUDE.md` requires explicit permission for dependency changes, the fix
was put as a question rather than applied; the answer was to bump it on this branch.
`bundle update json --conservative` changed exactly one gem line plus its checksum, with
`Gemfile` untouched. All four CI checks then passed locally.

**Verdict:** accepted

## Entry 7

> /code-review --comment

**Response:** The review could not post — no `gh`, no GitHub MCP tool — so it returned five
findings as text. Each was verified rather than taken on trust, which mattered: two of its
details were wrong. Blank content returns HTTP **422**, not the 500 it claimed, and the shallow
query cost **4** extra queries, not 5.

Its first finding was real and was my bug, already pushed:
`have_enqueued_job(...).with(Comment.last)` proved nothing, because Ruby evaluates the matcher
argument before the `expect` block runs, so `Comment.last` was `nil` and rspec-rails skips a nil
argument list. Confirmed by printing it at matcher-build time, then fixed with the block form
and proved by sabotage — enqueueing the tweet instead of the comment now fails the example.

Three further fixes were chosen: a unique index on both uuid columns (duplicate uuids were
accepted, and `find_by(uuid:)` was scanning), `RecordInvalid` rescued into a
`GraphQL::ExecutionError` in both mutations, and lookahead-driven preloading so a shallow query
costs one query again instead of five. A fourth problem surfaced while doing them, caused by my
own earlier change: making development multi-database meant `db:migrate` re-dumped
`db/queue_schema.rb` in the 8.1 dumper format on every run, so that file was committed once in
its regenerated form and verified stable. Suite went 44 → 51 examples. Verified in the running
app at 1, 3 and 6 queries for the shallow, resources-only and fully nested queries.

**Verdict:** accepted

## Entry 8

> /code-review --comment

**Response:** `gh` was present this time (`/usr/bin/gh`), and the review posted three inline
comments on PR #6 — confirmed by fetching them back rather than trusting the report.

One of the three does not survive checking. The claim was that on a checkout where the queue
database has not been schema-loaded, `bin/rails db:migrate` dumps an empty database over
`db/queue_schema.rb` and wipes every Solid Queue table definition. Tested both variants — queue
database deleted outright, and queue database present but zero bytes — and the file came through
unchanged at 141 lines and 11 tables in both. Rails does not dump a schema for a database it did
not migrate. The review had been candid that it only confirmed "the dump-on-migrate half",
which is the *primary* database, and that behaviour was already known and handled in `e7ee503`.

The other two stand and were deliberately left open. The job signature is not backward
compatible across a deploy with a non-empty queue — true, but this project has never deployed
and the shim would be dead code the day it lands. And `tweets` is unpaginated with no
`max_depth` or `max_complexity` on the schema — true, unchanged by this PR, and not in the
week 8 requirements. Nothing was committed this round.

**Verdict:** accepted

## Entry 9

> check PROMPTS.md, there are some entries missing. Add them, update the reflectiontto cover
> this work too. After that ask before and commiting and commit after getting my aproval

**Response:** Added Entries 6 to 9 — the `scan_ruby` failure and both code-review rounds had
gone unlogged, which is itself a miss against the logging rule. Extended the reflection to cover
the review rounds, and corrected its "nearly merged" section: the vacuous assertion was not
nearly merged, it was committed and pushed. Approval requested before committing, as asked.

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

That said, the two `/code-review` prompts earned their place. Between them they produced the
unique index, the graceful validation errors, the conditional preloading and — most valuable —
the vacuous assertion that planning could never have caught, because it was introduced after the
plan was written. Planning front-loaded the design decisions; review caught the execution slips.
Neither substitutes for the other.

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

A third rule is worth considering but has **not** been added, since it was not asked for: prove
an assertion by breaking the code it guards. The vacuous `.with(Comment.last)` would have been
caught the moment it was written by sabotaging `perform_later` and watching the example stay
green. That is a heavier habit than the existing red/green rule — it asks for a second,
deliberate falsification of every value-level assertion — so it is recorded here as a candidate
rather than slipped into the working agreements.

**What was merged or nearly merged despite being wrong.** Three things, in ascending order of
how badly they reflect on the process.

First, `spec/graphql/types/mutation_type_spec.rb` and `tweet_type_spec.rb` assert `fields.keys`
with `contain_exactly`, so both broke the moment `commentCreate` and `comments` were
registered. Those failures were treated as the red half of their steps — but the same
failure would look like collateral damage to be silenced, and updating an exact-match
assertion to match whatever the code now does is exactly how a type spec stops testing
anything. Worth watching for in review.

Second: the whole feature could have been declared done on `44 examples, 0 failures` while
`perform_later` was in fact raising in the development environment. The specs pass because the
test queue adapter never runs a job. Only driving the real app surfaced the missing
`solid_queue` tables. A green suite said nothing about it, and no reachable test would have.
That gap was closed in Entry 3.

Third, and worst, because this one was not *nearly* merged — it was committed, pushed, and sat
on the branch for two rounds:
`have_enqueued_job(OpenGraphExtractionJob).with(Comment.last)` asserted nothing. `Comment.last`
is `nil` when the matcher is built, and rspec-rails silently skips the argument check for a nil
argument list, so the example passed no matter which record the job was enqueued for. It was
written in the same session as a reflection paragraph warning about assertions that quietly stop
testing anything, and it took an external review to catch it. The lesson is narrow and
practical: a spec that has never failed for the reason it claims to test has not been proven to
work. The fix was verified by sabotage — break the production code, watch the example go red —
and that step should be routine for any assertion about *which* value was passed, not just that
something happened.

**On the code reviews.** Two rounds, and the pattern in both was the same: the review found
things worth fixing and also asserted things that were not true. Round one got the blank-content
status code wrong (422, not 500) and the shallow-query cost wrong (4 extra, not 5). Round two
claimed `db:migrate` would wipe `db/queue_schema.rb` on a fresh checkout, which does not
reproduce in either variant tested. Every finding that led to a code change was reproduced first;
the one that did not reproduce led to no change. That is the right ratio, and it is worth saying
plainly that a review — human or otherwise — is evidence to check, not an instruction to follow.

**What my own fixes broke.** Worth recording separately, because it is the failure mode that
scope discipline does not protect against. Giving development its own queue database (Entry 3)
was a correct fix that silently created a new problem: `db:migrate` began re-dumping
`db/queue_schema.rb` on every run. Nobody caught that at the time — not me, not the first
review. It surfaced two rounds later only because an unrelated migration made the churn visible
in `git status`. A fix landing cleanly and its consequences landing cleanly are different
claims, and only the first one gets verified by default.
