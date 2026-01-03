---
name: test
description: Run unit and UI tests
arguments:
  - name: type
    description: Test type (unit, ui, all). Defaults to all.
    required: false
  - name: platform
    description: Target platform (ios, mac). Defaults to mac.
    required: false
---

# Test Command

Run Xcode tests using xcodebuild.

## Usage

```
/test           # Run all tests on macOS
/test unit      # Run unit tests only
/test ui        # Run UI tests only
/test ios       # Run all tests on iOS Simulator
```

## Instructions

1. Determine which test target to run based on the type argument:
   - `unit` or `all`: Run `composerTests` target
   - `ui`: Run `composerUITests` target
   - If `all` or no type specified: Run both

2. Run the build script in test mode:

```bash
# For unit tests
bash "${CLAUDE_PLUGIN_ROOT}/scripts/build.sh" "{{platform|mac}}" "composerTests" test

# For UI tests
bash "${CLAUDE_PLUGIN_ROOT}/scripts/build.sh" "{{platform|mac}}" "composerUITests" test
```

3. Parse test results and report:
   - Number of tests passed
   - Number of tests failed
   - Failed test names and failure messages

4. If tests fail, analyze the failures:

   **For test assertion failures:**
   - Show the expected vs actual values
   - Show the test function and file location

   **For test crashes:**
   - Show the crash location
   - Suggest examining the code path

5. Ask the user if they want help fixing failing tests.

## Test Output Parsing

Look for patterns like:
```
Test Case '-[composerTests.SomeTest testExample]' passed (0.001 seconds)
Test Case '-[composerTests.SomeTest testFailing]' failed (0.002 seconds)
```

And assertion failures:
```
XCTAssertEqual failed: ("expected") is not equal to ("actual")
```
