# Release Process Documentation

This document describes the automated release process for the ProPresenter OneDrive Setup Assistant.

## Overview

The project uses GitHub Actions to automatically create releases when version tags are pushed to the repository. This ensures consistent, tested releases with proper packaging and documentation.

## Release Workflow

### Automatic Triggers

Releases are automatically created when:
- A git tag matching the pattern `v*.*.*` is pushed to the repository
- Example: `v1.0.0`, `v1.2.3`, `v2.1.0`

### Workflow Steps

1. **Validation Phase**:
   - Validates semantic version tag format
   - Checks script syntax using `bash -n`
   - Verifies executable permissions
   - Confirms environment configuration exists

2. **Package Creation**:
   - Creates clean release package with:
     - `ProPresenter-Setup-Assistant.command` (main script)
     - `lib/` directory (modular components)
     - `docs/` directory (documentation)
     - `LICENSE` and `README.md` (if present)
   - Generates ZIP archive named `propresenter-setup-assistant-v{version}.zip`

3. **Testing**:
   - Tests ZIP extraction
   - Validates extracted script syntax
   - Confirms executable permissions are preserved

4. **Release Creation**:
   - Creates GitHub release with standardized naming
   - Generates automatic release notes from commit history
   - Uploads ZIP asset to the release

## Creating a Release

### Step 1: Prepare the Release

1. Ensure all changes are committed and merged to the main branch
2. Update version number in the script if needed:
   ```bash
   # In ProPresenter-Setup-Assistant.command
   SCRIPT_VERSION="1.0.0"  # Update this version
   ```
3. Test the script locally to ensure it works correctly

### Step 2: Create and Push Version Tag

```bash
# Create annotated tag with release notes
git tag -a v1.0.0 -m "Release v1.0.0: Core infrastructure and GitHub release automation"

# Push the tag to trigger the workflow
git push origin v1.0.0
```

### Step 3: Monitor Workflow

1. Go to the "Actions" tab in the GitHub repository
2. Watch the "Create Release" workflow execution
3. Verify all steps complete successfully

### Step 4: Verify Release

1. Check the "Releases" section of the GitHub repository
2. Confirm the release appears with:
   - Correct version number and title
   - Generated release notes
   - ZIP asset attachment
3. Test downloading and extracting the ZIP file

## Version Numbering

The project follows [Semantic Versioning](https://semver.org/) (SemVer):

- **MAJOR** version: Incompatible API changes or major functionality changes
- **MINOR** version: New functionality in a backward-compatible manner
- **PATCH** version: Backward-compatible bug fixes

### Examples:
- `v1.0.0`: Initial release with core infrastructure
- `v1.1.0`: Added self-updating functionality
- `v1.1.1`: Fixed bug in environment configuration parsing
- `v2.0.0`: Major restructure or breaking changes

## Release Asset Structure

Each release includes a ZIP file containing:

```
propresenter-setup-assistant-v{version}.zip
├── ProPresenter-Setup-Assistant.command    # Main executable script
├── lib/                                     # Modular components (future use)
├── docs/                                    # Complete documentation
│   ├── app-design/
│   │   ├── design.md
│   │   └── environment.md
│   ├── release-planning/
│   └── RELEASE_PROCESS.md
├── LICENSE                                  # License file (if present)
└── README.md                               # Project readme (if present)
```

## Troubleshooting

### Common Issues

1. **Tag format validation fails**:
   - Ensure tag follows exact format: `v1.2.3`
   - No additional characters or suffixes

2. **Script syntax validation fails**:
   - Test locally with `bash -n ProPresenter-Setup-Assistant.command`
   - Fix any syntax errors before tagging

3. **Permission issues**:
   - Ensure script has executable permissions: `chmod +x ProPresenter-Setup-Assistant.command`
   - Commit permission changes before tagging

4. **Workflow permissions**:
   - Repository must have "Actions" enabled
   - Workflow needs `contents: write` permission (already configured)

### Manual Release Creation

If automated release fails, create manually:

1. Go to GitHub repository "Releases" section
2. Click "Create a new release"
3. Choose or create the version tag
4. Upload the ZIP file manually
5. Add release notes

## Security Considerations

- Only authorized maintainers should create release tags
- All releases are publicly downloadable
- No sensitive information should be included in releases
- Environment configuration contains organization-specific but non-sensitive data

## Future Enhancements

Planned improvements to the release process:
- Code signing for macOS distribution
- Automated testing on multiple macOS versions
- Release candidate (RC) workflow for testing
- Automatic changelog generation
- Integration with package managers (Homebrew)