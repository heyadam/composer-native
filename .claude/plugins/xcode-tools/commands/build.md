---
name: build
description: Build the Xcode project for iOS or macOS
arguments:
  - name: platform
    description: Target platform (ios, mac). Defaults to mac.
    required: false
  - name: scheme
    description: Xcode scheme to build. Defaults to 'composer'.
    required: false
---

# Build Command

Build the Xcode project using xcodebuild.

## Usage

```
/build          # Build for macOS (default)
/build ios      # Build for iOS Simulator
/build mac      # Build for macOS
```

## Instructions

1. Run the build script with the specified platform:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/build.sh" "{{platform|mac}}" "{{scheme|composer}}" build
```

2. If the build succeeds, report the success to the user.

3. If the build fails, parse the error output and:

   **For safe fixes (auto-apply without asking):**
   - Missing `import` statements - add the import
   - Missing `await` keyword - add await
   - Unused variable warnings - prefix with underscore
   - Simple typos where the compiler suggests the correct name

   **For complex fixes (ask the user first):**
   - Type mismatches requiring logic changes
   - Missing protocol conformances
   - Architectural issues
   - Any fix requiring deletion of code
   - Ambiguous fixes with multiple solutions

4. After applying fixes, run the build again to verify.

## Error Parsing

Extract errors in this format:
- File path (relative to project root)
- Line number
- Error message
- Compiler suggestion (if any)

Example error format:
```
/path/to/File.swift:42:15: error: cannot find 'foo' in scope
```

Parse as:
- File: `/path/to/File.swift`
- Line: 42
- Column: 15
- Message: "cannot find 'foo' in scope"
