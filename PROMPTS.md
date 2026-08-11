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
