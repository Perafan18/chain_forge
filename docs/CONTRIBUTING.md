# Contributing to ChainForge

Thank you for your interest in contributing! ChainForge is an educational project focused on blockchain fundamentals.

## Code of Conduct

Be respectful, constructive, and helpful. This is a learning environment.

## Development Setup

### Prerequisites
- Ruby 3.2.2 (via rbenv)
- MongoDB
- Git

### Setup Steps

```bash
# Clone repository
git clone https://github.com/Perafan18/chain_forge.git
cd chain_forge

# Install Ruby version
rbenv install 3.2.2
rbenv local 3.2.2

# Install dependencies
bundle install

# Configure environment
cp .env.example .env
# Edit .env: set DEFAULT_DIFFICULTY, MongoDB config

# Start MongoDB
docker-compose up -d mongodb

# Run tests
bundle exec rspec
```

## Development Workflow

### 1. Create a Branch

```bash
git checkout -b feature/your-feature-name
```

Branch naming conventions:
- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation only
- `refactor/` - Code refactoring
- `test/` - Test improvements

### 2. Make Changes

- Write clear, readable code (educational value is key)
- Add/update tests for new features
- Follow RuboCop style guidelines
- Update documentation

### 3. Test Your Changes

```bash
# Run RuboCop
bundle exec rubocop

# Auto-fix style issues
bundle exec rubocop -a

# Run tests with coverage
COVERAGE=true bundle exec rspec

# Aim for >90% coverage
open coverage/index.html
```

### 4. Commit

```bash
git add .
git commit -m "feat: Clear description of changes"
```

Commit message format:
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation
- `refactor:` - Code refactoring
- `test:` - Test changes
- `chore:` - Maintenance

### 5. Push and Create PR

```bash
git push origin feature/your-feature-name
```

Then open a Pull Request on GitHub with:
- Clear description of changes
- Why the change is needed
- How to test it
- Any breaking changes

## Code Style

### Ruby Style

Follow RuboCop guidelines (`.rubocop.yml`):
- Use single quotes for strings
- 2-space indentation
- Max line length: 120 characters
- Frozen string literal comments

### Code Quality

- Keep methods short and focused
- Use meaningful variable names
- Comment complex logic (explain "why", not "what")
- Avoid premature optimization
- Maintain educational clarity

## Testing Guidelines

### Test Structure

```ruby
RSpec.describe Feature do
  describe '#method' do
    context 'when condition' do
      it 'does something specific' do
        # Arrange
        object = create_object

        # Act
        result = object.method

        # Assert
        expect(result).to eq(expected)
      end
    end
  end
end
```

### Testing Best Practices

- **Test behavior, not implementation**
- **Use descriptive test names**: "returns error when data is empty"
- **Test edge cases**: empty strings, nil values, boundary conditions
- **Test error handling**: 404, 400, 429 status codes
- **Mock external dependencies**: but use real MongoDB in tests
- **Keep tests fast**: Use difficulty 1-2 for mining tests

### Coverage Requirements

- Aim for >90% test coverage
- All new features must include tests
- Test both happy paths and error cases
- Run `COVERAGE=true bundle exec rspec` before submitting

## Documentation

### When to Update Docs

Update documentation when:
- Adding new features
- Changing API endpoints
- Modifying environment variables
- Changing architecture
- Adding dependencies

### Files to Update

- **README.md**: User-facing features and API
- **CLAUDE.md**: Developer architecture and workflow
- **CHANGELOG.md**: All changes (following Keep a Changelog format)
- **API_DOCUMENTATION.md**: Complete endpoint changes
- **Inline comments**: Complex logic

## Educational Focus

Remember, this is a learning project:

### Prioritize
- ✅ **Clarity**: Clear, understandable code
- ✅ **Comments**: Explain complex concepts
- ✅ **Simplicity**: Simple implementations
- ✅ **Documentation**: Well-documented features

### Avoid
- ❌ **Premature optimization**: Don't sacrifice clarity for speed
- ❌ **Complex abstractions**: Keep it simple
- ❌ **Production shortcuts**: Implement correctly, even if educational

## Pull Request Process

### Before Submitting

- [ ] All tests pass (`bundle exec rspec`)
- [ ] RuboCop passes (`bundle exec rubocop`)
- [ ] Coverage >90% (`COVERAGE=true bundle exec rspec`)
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Commit messages are clear
- [ ] No `.env` or sensitive data committed

### PR Review Process

1. **Automated Checks**: GitHub Actions runs RuboCop + RSpec
2. **Code Review**: Maintainer reviews code quality and tests
3. **Feedback**: Address any requested changes
4. **Approval**: Once approved, PR will be merged
5. **Merge**: Squash and merge to main branch

### Getting Feedback

- Be patient, reviews may take a few days
- Respond to feedback constructively
- Ask questions if feedback is unclear
- Make requested changes promptly

## Common Contribution Areas

### Good First Issues

- Documentation improvements
- Test coverage improvements
- Bug fixes
- Code comments
- Example scripts

### Advanced Contributions

- New API endpoints
- Performance optimizations
- Security enhancements
- Monitoring features
- Advanced PoW features

## API Changes

### Adding New Endpoints

When adding API endpoints:

1. Use `/api/v1` namespace
2. Add rate limiting in `config/rack_attack.rb`
3. Create validation contract in `src/validators.rb`
4. Add tests in `spec/api_spec.rb`
5. Update README.md and API_DOCUMENTATION.md
6. Consider backward compatibility

### Breaking Changes

Avoid breaking changes when possible. If necessary:

1. Discuss in issue first
2. Document in CHANGELOG.md (Breaking Changes section)
3. Update README.md with migration guide
4. Increment major version (2.x.x → 3.0.0)

## Environment Variables

### Adding New Env Vars

When adding environment variables:

1. Add to `.env.example` with comment
2. Add to `.env.test` if needed for tests
3. Document in README.md Configuration section
4. Document in CLAUDE.md
5. Use `ENV.fetch('VAR', 'default')` in code

## Questions?

- Open an issue for discussion
- Ask in pull request comments
- Check existing documentation
- Review similar contributions

## Recognition

Contributors will be:
- Listed in git commit history
- Mentioned in release notes
- Appreciated for making blockchain education better!

Thank you for contributing to ChainForge! 🎉
