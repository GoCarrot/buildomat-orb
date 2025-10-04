# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is the Buildomat CircleCI Orb - a custom CircleCI orb that provides reusable commands and jobs for infrastructure automation using Terraform, Packer, and Deployomat (a custom deployment orchestration tool).

## Development Commands

### Validation and Testing
- `rake validate` - Validate the orb structure
- `rake shellcheck` - Run shellcheck on all scripts in src/scripts/
- `rake test` - Run both validation and shellcheck

### Publishing
- `rake publish` - Publish the orb with dev:alpha label for testing
- `rake promote:patch` - Promote dev:alpha to production with patch version bump
- `rake promote:minor` - Promote dev:alpha to production with minor version bump  
- `rake promote:major` - Promote dev:alpha to production with major version bump

### Development Helpers
- `rake dev:parameter_template` - Generate CircleCI environment blocks for parameters
- `rake dev:script_template` - Generate bash script templates for parameter parsing

## Architecture

### Core Components

1. **Commands** (`src/commands/`): Reusable CircleCI command definitions
   - `terraform-*` - Terraform operations (init, plan, apply)
   - `packer-*` - Packer operations (init, build)
   - `deployomat-*` - Custom deployment system operations
   - `aws-oidc-assume` - AWS role assumption via OIDC
   - `hashicorp-install` - Install Terraform/Packer binaries

2. **Jobs** (`src/jobs/`): Complete CircleCI job definitions that compose commands
   - `terraform-plan`, `terraform-apply` - Full Terraform workflows
   - `packer-build` - Complete Packer build workflow
   - `deployomat-deploy`, `deployomat-cancel` - Deployment orchestration
   - `build-dependent-images` - AMI dependency management
   - Various Slack notification jobs for approval workflows

3. **Scripts** (`src/scripts/`): Bash scripts that implement the actual logic
   - Each command typically has a corresponding shell script
   - Scripts handle parameter parsing, AWS operations, and tool invocations

4. **Orb Definition** (`src/@orb.yml`): Main orb configuration with dependencies

### Key Design Patterns

- **AWS OIDC Authentication**: The orb uses OIDC for AWS authentication rather than static credentials
- **Terraform Workspace Support**: Built-in support for Terraform workspaces
- **Continuation Pipelines**: Support for CircleCI continuation to handle complex workflows
- **Artifact Persistence**: Plan files and logs are persisted between jobs using CircleCI workspaces
- **Slack Integration**: Built-in Slack notifications for approval steps
- **HashiCorp Tool Management**: Automatic download and verification of Terraform/Packer binaries

### Default Versions
- Terraform: 1.10.5
- Packer: 1.12.0

## Prerequisites

- Install dependencies: `brew bundle`
- Organization name: `teak`
- Orb name: `buildomat`