## Buildomat CircleCI Orb

Development requires that you have the circleci CLI installed. `brew install circleci`

### Deployment

`rake validate` to validate the orb
`rake publish` to make the orb available with the dev:alpha label
`rake promote:(major|minor|patch)` to publish the `dev:alpha` orb bumping the given version number.
