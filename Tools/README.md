# AutoRecall Tools

This directory contains utilities and tools for developing, testing, and maintaining the AutoRecall application.

## TestUtility.swift

`TestUtility.swift` is a comprehensive testing utility that consolidates the functionality from various test scripts into a single, easy-to-use tool. It provides a command-line interface for running different types of tests on the AutoRecall application.

### Usage

```bash
./TestUtility.swift [options]
```

### Options

- `--all`: Run all tests
- `--database`: Run database tests
- `--screenshot`: Run screenshot tests
- `--clipboard`: Run clipboard tests
- `--text-input`: Run text input tests
- `--storage`: Run storage tests
- `--performance`: Run performance tests
- `--memory`: Run memory tests
- `--help`: Display help message

### Examples

Run all tests:
```bash
./TestUtility.swift --all
```

Run only database and storage tests:
```bash
./TestUtility.swift --database --storage
```

## Using with Makefile

The tools in this directory are integrated with the project's Makefile. You can run tests using:

```bash
make test-all
```

This will execute the TestUtility with all test categories enabled.

## Adding New Tests

To add new test categories:

1. Add a new case to the `TestCategory` enum in `TestUtility.swift`
2. Implement the corresponding test method in the `TestUtility` struct
3. Add the new option to the command-line argument processing section

## Integration with CI/CD

These tools are designed to be easily integrated with continuous integration systems. For example, to run tests as part of a CI pipeline, use:

```bash
make test-all
```

## Development Notes

- The TestUtility is designed to run tests without requiring the full application to be launched
- All tests are non-destructive and safe to run on development and production environments
- Performance tests will report metrics but will not modify any settings
- Memory tests analyze current application memory usage patterns 