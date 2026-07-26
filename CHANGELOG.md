## 0.1.10

BUG FIXES:

* `terraform-plan`: the `lock` param's string comparison only matched the
  literal word `false`, but CircleCI stringifies a boolean `false` to `0` when
  materializing an `environment:` block — so `lock: false` never actually
  reached `terraform plan` as `-lock=false`. Now matches both renderings.

ENHANCEMENTS:

* `terraform-plan`: logs the fully-built `terraform plan` argument string
  before running it, so a param like `lock` can be confirmed reaching the
  actual invocation rather than inferred from the env-var echo alone.

## 0.1.9

ENHANCEMENTS:

* `terraform-plan` command/job: new opt-in `lock` parameter (default `true`,
  matching existing behavior). Set to `false` for a plan whose output is
  discarded and never applied, to skip taking the state lock.

## 0.1.5

ENHANCEMENTS:

* Use CIRCLE_OIDC_TOKEN_V2 when assuming an AWS role.

## 0.1.4

BUG FIXES:

* Approval deploys might work now

## 0.1.3

BUG FIXES:

* hashicorp install might work now

## 0.1.2

BUG FIXES:

* generate-continue's default output path now aligns with terraform-continuation's default continuation path.

## 0.1.1

BUG FIXES:

* build-dependent-images might work now

## 0.1.0

Initial release.
