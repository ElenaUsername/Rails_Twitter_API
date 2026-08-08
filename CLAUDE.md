# Working agreements

## Red/Green cycle — non-negotiable

All implementation follows the Red/Green cycle:

1. Write the RSpec test **before** the implementation.
2. Run it and confirm it **fails** — and fails for the right reason, not because of a typo
   or a missing constant.
3. Write **strictly the code necessary** to make it pass. Nothing more.
4. Re-run and confirm green.

Never write the implementation first and the test afterwards. Never write a test that
passes on the first run and call that done.

## Running tests

Always use `bundle exec rspec` — never a bare `rspec`.

When a test fails, **read the stack trace and the exact error message before changing
anything**. Do not guess at a fix, and do not try several speculative changes to see which
one sticks. Identify the actual cause from the output, then make the single change that
addresses it.

## Scope

Follow the provided requirements strictly. Do not guess at intent, and do not add extra
features, options, abstractions, or "while I was in there" improvements on your own
initiative. If a requirement is ambiguous, ask rather than assume.

## Secrets

Never commit API keys, tokens, passwords, or any sensitive data. Configuration of this kind
comes exclusively from environment variables — `.env` files and equivalents.

## Dependencies

Do **not** add, modify, or remove any gem in the `Gemfile` without explicit prior
permission. Fulfil requirements using the tools and packages already present in the
project.

---

Commit conventions — granularity, message format, and the RuboCop check that must pass
before every commit — live in `.claude/rules/feature-development.md`.
