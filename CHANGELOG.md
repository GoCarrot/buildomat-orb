## 0.1.14

ENHANCEMENTS:

* `terraform-multi-root-continuation` job (and `generate-multi-root-continue`
  command): the per-root Slack notification now links the root's plan log, the
  same artifact URL the single-root path uses, instead of the plan job.
* `terraform-slack-on-hold` job / `terraform-slack-on-hold-message` command:
  `root` now only names the root in the message; the link is always the plan
  log you pass in `plan-log-url`.
* `terraform-plan` with `continuation: true` no longer writes the `plan_job_url`
  file added in 0.1.13; the plan log URL is `plan-log-url` in `continue_params.json`.

## 0.1.13

ENHANCEMENTS:

* `terraform-multi-root-continuation` job (and `generate-multi-root-continue`
  command): new `slack_contexts` param. When set, each root with changes gets a
  `terraform-slack-on-hold` job, run with just those contexts, that runs
  alongside its approval hold (the hold doesn't wait on it). Empty (default) keeps today's output. Roots with no
  changes still get nothing, so a run with no changes posts nothing.
* `terraform-slack-on-hold` job / `terraform-slack-on-hold-message` command:
  new `root` param. When set, the message names the root and links the plan job
  instead of a plan log. Unset, the message is unchanged.
* `terraform-plan` with `continuation: true` writes a `plan_job_url` file next
  to `continue_params.json` when the plan has changes.

## 0.1.12

ENHANCEMENTS:

* New `terraform-multi-root-continuation` job (and `generate-multi-root-continue`
  command) for repos with several terraform roots. After one `terraform-plan`
  per root, it continues with an approval hold + apply for each root whose plan
  has changes, and nothing for the rest. When no root changed it ends green
  without continuing. Plans must use cache key
  `{{ .Environment.CIRCLE_WORKFLOW_ID }}-<root>-plan`; the apply restores
  from the plan job's workflow id, so a rerun-from-failed still finds it.
* `terraform-plan` command/job: new `continuation_cache_key` param (default
  unchanged, the workflow id). Several plans in one workflow need distinct
  keys, since the first save to a key wins.
* `terraform-plan` job: new `persist_root` param (default unchanged,
  `out_path`). Point it at a parent of `out_path` so parallel plans keep their
  own subdirectory in the workspace instead of overwriting each other.
* `terraform-plan` command/job: new `store_plan_artifact` param (default
  unchanged, `true`). A planfile holds data-source results in plaintext,
  including decrypted `aws_kms_secrets`; set `false` to keep it out of
  downloadable job artifacts. The continuation cache still gets it.

## 0.1.11

BUG FIXES:

* `terraform-init`: runs `terraform init -reconfigure`. The command restores a
  cache that includes `.terraform/terraform.tfstate` (the saved backend
  config), keyed only on the provider lock file, so a change to the backend
  block with an unchanged lock file failed with "Backend configuration
  changed". CI never migrates state, so the checked-in backend config now
  always wins.

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
