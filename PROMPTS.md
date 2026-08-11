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

## Reflection

> **Draft — for review.** This is Claude's own read of the session; the judgements below are
> the ones a human should confirm, correct or overrule before this section is treated as final.

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

**What rule would prevent repeating a correction.** Nothing in `CLAUDE.md` needed to change to
get this right, so proposing a new rule would be inventing a problem. The closest thing to a
real gap: the existing rules say to reuse rather than duplicate, but say nothing about what to
do when reuse requires *modifying* existing working code — here, making `resource_descriptions`
polymorphic and rewriting `Tweet` touched three files that had nothing wrong with them. That
was the right move, and it was cheap only because 27 green specs made it safe. If a rule is
wanted, it is about that precondition: refactor existing code in service of reuse only behind
a green suite, and commit the refactor separately from the feature that motivated it.

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
the missing `solid_queue` tables. A green suite said nothing about it.
