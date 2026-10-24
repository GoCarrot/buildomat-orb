## Buildomat CircleCI Orb

A CircleCI orb that provides reusable workflows for infrastructure automation using Terraform, Packer, and Deployomat.

## Usage

### Basic Terraform Workflow with Continuation

Buildomat uses CircleCI's [dynamic configuration](https://circleci.com/docs/dynamic-config/) to conditionally run terraform apply, packer builds, and deployments based on whether your infrastructure has changes.

#### Minimal Setup

**`.circleci/config.yml`** (setup pipeline):

```yaml
version: 2.1

setup: true

orbs:
  buildomat: teak/buildomat@0.1

workflows:
  terraform:
    jobs:
      # Run terraform plan and check for changes
      - buildomat/terraform-plan:
          path: "terraform"
          workspace: "production"
          continuation: true
          context: AWS-OIDC-Role

      # Generate continue.yml and trigger continuation pipeline
      - buildomat/terraform-continuation:
          requires:
            - buildomat/terraform-plan
          before_continuation_steps:
            - buildomat/generate-continue:
                orb: "teak/buildomat@0.1"
                terraform_version: "1.10.5"
                packer_version: "1.12.0"
                contexts: "AWS-OIDC-Role"
```

That's it! The `terraform-continuation` job will:

1. Check if terraform detected changes (via `continue_params.json` from the plan step)
2. Generate a `.circleci/continue.yml` with the full workflow
3. Trigger the continuation pipeline with conditional workflows

#### What Happens Next

The generated `continue.yml` contains three conditional workflows:

- **`apply-and-build`** - When `run-apply: true` (terraform has changes):
  - Sends Slack notification for approval
  - Waits for manual approval
  - Runs `terraform apply`
  - Builds AMIs with Packer
  - Deploys services

- **`build-and-deploy-only`** - When no terraform changes but you want deploys:
  - Skips terraform apply
  - Builds AMIs with Packer
  - Deploys services

- **`build-only`** - When no terraform changes and no deployments needed:
  - Only builds AMIs with Packer

#### Adding Service Deployments

Configure which services to deploy in the `generate-continue` step:

```yaml
- buildomat/generate-continue:
    orb: "teak/buildomat@0.1"
    # Auto-deploy without rollback option (e.g., launch template updates)
    auto_deploy_no_rollback_services: "api-console,background-worker"
    # Auto-deploy with rollback option
    auto_deploy_services: "staging-api"
    # Require approval before deploying
    approve_deploy_services: "production-api"
```

#### Multi-Environment Setup

Use branch filters and workspace parameters for different environments:

```yaml
- buildomat/terraform-plan:
    name: "Plan (Development)"
    workspace: "dev"
    continuation: true
    continuation_parameters: "deploy_account_slug=dev"
    filters:
      branches:
        only: develop

- buildomat/terraform-plan:
    name: "Plan (Production)"
    workspace: "prod"
    continuation: true
    continuation_parameters: "deploy_account_slug=prod"
    filters:
      branches:
        only: main
```

#### Requiring Tests Before Deploy

Gate the continuation on your test suite:

```yaml
workflows:
  terraform:
    jobs:
      - test
      - buildomat/terraform-plan:
          continuation: true
      - buildomat/terraform-continuation:
          requires:
            - test  # Won't continue if tests fail
            - buildomat/terraform-plan
```

## Development

Development requires that you have the circleci CLI installed. `brew install circleci`

### Publishing

CI publishes. Every push runs `test`. A push to `main` then runs `test` ->
`publish` -> `hold` -> `promote`:

* `publish` pushes the commit to `teak/buildomat@dev:<sha>` and `dev:alpha`.
* `hold` is a manual approval in CircleCI. Nothing ships without it.
* `promote` reads the commit **subject** (not the body) for
  `Promote to: patch|minor|major` and runs `rake promote:<bump>[<sha>]`,
  promoting that commit's `dev:<sha>`. No marker means it ends green and
  publishes nothing; an unknown value (`Promote to: 0.2.0`) fails.

Consumers float on `@0.1`, so a promote is a fleet-wide release. Before
asking for one, add the `CHANGELOG.md` entry titled with exactly the version the
bump will publish (0.1.12 + `patch` = `## 0.1.13`). The gate fails the job
before publishing if it isn't.

A default "Merge pull request #N" commit never carries the marker; its subject
is the merge boilerplate. To ask for a promote, do one of:

* edit the merge-commit title in GitHub's merge dialog to `Promote to: patch`
* squash-merge with the PR title `Promote to: patch`
* push a commit to `main` whose subject is `Promote to: patch`

`publish` and `promote` run in the `CircleCI` context, whose
`CIRCLE_API_TOKEN` is the API token for the orb CLI. That token has to be
allowed to publish `teak/buildomat`.

#### Break-glass

From a laptop with `circleci setup` done:

`rake validate` to validate the orb
`rake publish` to make the orb available with the dev:alpha label (`rake publish[label]` for `dev:label`)
`rake promote:(major|minor|patch)` to publish the `dev:alpha` orb bumping the given version number (`rake promote:patch[label]` for `dev:label`).

Note `dev:alpha` is shared: a CI publish or someone else's branch publish may
have replaced what you pushed. Check before you promote it.
