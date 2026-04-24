---
description: 'Generic code review instructions for GitHub Copilot — structured review priorities, clean code standards, security, testing, performance, architecture, and documentation checks'
applyTo: '**'
excludeAgent: ["coding-agent"]
---

<!--
Source: https://github.com/github/awesome-copilot/blob/main/instructions/code-review-generic.instructions.md
License: MIT (github/awesome-copilot)
-->

# Generic Code Review Instructions

Comprehensive code review guidelines for GitHub Copilot that can be adapted to any project. These instructions follow best practices from prompt engineering and provide a structured approach to code quality, security, testing, and architecture review.

## Review Priorities

When performing a code review, prioritize issues in the following order:

### 🔴 CRITICAL (Block merge)
- **Security**: Vulnerabilities, exposed secrets, authentication/authorization issues
- **Correctness**: Logic errors, data corruption risks, race conditions
- **Breaking Changes**: API contract changes without versioning
- **Data Loss**: Risk of data loss or corruption

### 🟡 IMPORTANT (Requires discussion)
- **Code Quality**: Severe violations of SOLID principles, excessive duplication
- **Test Coverage**: Missing tests for critical paths or new functionality
- **Performance**: Obvious performance bottlenecks
- **Architecture**: Significant deviations from established patterns

### 🟢 SUGGESTION (Non-blocking improvements)
- **Readability**: Poor naming, complex logic that could be simplified
- **Optimization**: Performance improvements without functional impact
- **Best Practices**: Minor deviations from conventions
- **Documentation**: Missing or incomplete comments/documentation

## General Review Principles

1. **Be specific**: Reference exact lines, files, and provide concrete examples
2. **Provide context**: Explain WHY something is an issue and the potential impact
3. **Suggest solutions**: Show corrected code when applicable, not just what's wrong
4. **Be constructive**: Focus on improving the code, not criticizing the author
5. **Recognize good practices**: Acknowledge well-written code and smart solutions
6. **Be pragmatic**: Not every suggestion needs immediate implementation

## Code Quality Standards

### Clean Code
- Descriptive and meaningful names for variables, functions, and classes
- Single Responsibility Principle: each function/class does one thing well
- DRY (Don't Repeat Yourself): no code duplication
- Functions should be small and focused
- Avoid deeply nested code (max 3-4 levels)
- Avoid magic numbers and strings (use constants)

### Error Handling
- Proper error handling at appropriate levels
- Meaningful error messages
- No silent failures or ignored exceptions
- Fail fast: validate inputs early

## Security Review

When performing a code review, check for security issues:

- **Sensitive Data**: No passwords, API keys, tokens, or PII in code or logs
- **Input Validation**: All user inputs are validated and sanitized
- **SQL Injection**: Use parameterized queries, never string concatenation
- **Authentication**: Proper authentication checks before accessing resources
- **Authorization**: Verify user has permission to perform action
- **Cryptography**: Use established libraries, never roll your own crypto
- **Dependency Security**: Check for known vulnerabilities in dependencies

### IaC-Specific Security
- **Hardcoded secrets**: No credentials, keys, or passwords in Terraform/Ansible/Helm files
- **Least privilege**: IAM roles, security groups, and RBAC scoped to minimum required
- **Encryption**: Data at rest and in transit encrypted by default
- **Private networking**: Resources in private subnets unless explicitly justified
- **Version pinning**: All provider, module, and image versions pinned

## Testing Standards

When performing a code review, verify test quality:

- **Coverage**: Critical paths and new functionality must have tests
- **Test Names**: Descriptive names that explain what is being tested
- **Test Structure**: Clear Arrange-Act-Assert or Given-When-Then pattern
- **Independence**: Tests should not depend on each other or external state
- **Edge Cases**: Test boundary conditions, null values, empty collections

## Performance Considerations

- **Algorithms**: Appropriate time/space complexity for the use case
- **Caching**: Utilize caching for expensive or repeated operations
- **Resource Management**: Proper cleanup of connections, files, streams

## Architecture and Design

- **Separation of Concerns**: Clear boundaries between layers/modules
- **Loose Coupling**: Components should be independently testable
- **High Cohesion**: Related functionality grouped together
- **Consistent Patterns**: Follow established patterns in the codebase

## Documentation Standards

- **API Documentation**: Public APIs must be documented
- **Complex Logic**: Non-obvious logic should have explanatory comments
- **README Updates**: Update README when adding features or changing setup
- **Breaking Changes**: Document any breaking changes clearly

## Review Checklist

### Code Quality
- [ ] Code follows consistent style and conventions
- [ ] Names are descriptive and follow naming conventions
- [ ] No code duplication
- [ ] Error handling is appropriate
- [ ] No commented-out code or TODO without tickets

### Security
- [ ] No sensitive data in code or logs
- [ ] Input validation on all user inputs
- [ ] Authentication and authorization properly implemented
- [ ] Dependencies are up-to-date and secure
- [ ] No secrets hardcoded (use variables/secrets managers)

### Testing
- [ ] New code has appropriate test coverage
- [ ] Tests are well-named and focused
- [ ] Tests cover edge cases and error scenarios

### Performance
- [ ] No obvious performance issues
- [ ] Proper resource cleanup

### Architecture
- [ ] Follows established patterns and conventions
- [ ] Proper separation of concerns

### Documentation
- [ ] Public APIs are documented
- [ ] Complex logic has explanatory comments
- [ ] README is updated if needed
- [ ] Breaking changes are documented
