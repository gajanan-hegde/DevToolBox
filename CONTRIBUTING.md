# Contributing to DevToolbox

Thanks for your interest in contributing! Here's how to get involved.

## Reporting Bugs

1. Search [existing issues](https://github.com/YOUR_USERNAME/DevToolbox/issues) to avoid duplicates.
2. Open a new issue and include:
   - macOS version
   - Steps to reproduce
   - What you expected vs. what happened
   - Screenshots or logs if relevant

## Requesting Features

Open an issue with the label `enhancement`. Describe the problem you're trying to solve, not just the solution you have in mind — this helps with discussion.

## Submitting Pull Requests

1. **Fork** the repository and create a branch from `main`:
   ```bash
   git checkout -b feature/my-improvement
   ```
2. Make your changes. Keep them focused — one feature or fix per PR.
3. Match the existing Swift style (no formatter config required — follow what's already there).
4. **Commit** with a clear message:
   ```bash
   git commit -m "Add URL scheme support for YAML tool"
   ```
5. **Push** your branch and open a pull request against `main`.
6. Describe what you changed and why in the PR description.

## Code Style

- SwiftUI and Swift idioms over UIKit patterns
- Prefer value types (`struct`) over classes where appropriate
- No third-party dependencies — keep it self-contained

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
