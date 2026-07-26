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
