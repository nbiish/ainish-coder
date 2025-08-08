# Security Progress Log

Date (America/New_York): 2025-08-07 19:56

## Changes

- Adjusted Cursor deploy verification to treat `.cursorrules` as optional and avoid false warnings during `ainish-cursor` runs on repos without that file.
- Ensured Cursor launches with `NODE_OPTIONS=--force-node-api-uncaught-exceptions-policy=true` to properly handle N-API uncaught exceptions and silence the deprecation warning.

## Impact

- Reduces noise during verification and prevents confusion when `.cursorrules` is intentionally absent.
- Improves runtime resilience and avoids deprecation warnings when launching Cursor via wrapper.

## Next

- Consider adding an env toggle to enable/disable the Node option and documenting `.cursorrules` optionality in README.
