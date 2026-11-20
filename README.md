# optilint action

Runs [optilint](https://optilint.pages.dev) on a pull request and shows its findings as annotations on the diff: slow patterns in JavaScript and TypeScript, each with the fix optilint would make and what that fix guarantees.

```yaml
name: optilint
on: [pull_request]
permissions: {}
jobs:
  optilint:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v7
        with:
          persist-credentials: false
      - uses: tjagithub/optilint-action@v0
```

It runs `npx @optilint/cli`, so it needs Node on the runner (GitHub's hosted runners have it) and reads your `optilint.json` and `tsconfig.json`. Pin the action to a commit SHA in production workflows.

## Inputs

| Input | Default | |
|---|---|---|
| `paths` | `.` | Files or folders to lint, separated by spaces. |
| `version` | `0` | The `@optilint/cli` version or range. |
| `working-directory` | `.` | Where to run; its config and tsconfig apply. |
| `min-impact` | `low` | Only report `high`, `medium` or `low` and up. |
| `fail-on` | `findings` | `findings`: fail on any finding not set to `info`. `error`: only on `error` severity. `never`: only annotate. |
| `sarif` | `false` | Also upload SARIF to code scanning. Needs `security-events: write`. |
| `args` | | More optilint flags, such as `--disable loops`. |

Outputs: `findings` (the count) and `sarif-file`.

## Fixing

The action only reports. Apply fixes where you can review them: `npx @optilint/cli --fix` locally, `--ui` to pick fixes by tier, or the VS Code extension's quick fixes.

## License

MIT
