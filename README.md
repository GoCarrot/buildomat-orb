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

### Deployment

`rake validate` to validate the orb
`rake publish` to make the orb available with the dev:alpha label
`rake promote:(major|minor|patch)` to publish the `dev:alpha` orb bumping the given version number.
