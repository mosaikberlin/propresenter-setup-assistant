# Release Process Documentation

This document describes the automated release process for the ProPresenter OneDrive Setup Assistant.

## Overview

The project uses GitHub Actions to automatically create releases when changes are pushed to the main branch. The workflow is **documentation-driven** and **version-file-based**, ensuring consistent, tested releases with proper packaging.

## Release Workflow

### Automatic Triggers

Releases are automatically created when:
- Changes are pushed to the `main` branch
- A `VERSION` file exists with a valid version number
- Release documentation exists at `docs/releases/v{version}.md`
- No existing release exists for that version

### Version Management

- **Single Source of Truth**: Version is stored in the `VERSION` file in the repository root
- **Script Integration**: The main script reads its version from this file dynamically
- **No Manual Tagging**: The workflow creates git tags automatically

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

### Step 1: Update Version Number

1. Update the version in the `VERSION` file:
   ```bash
   echo "1.2.0" > VERSION
   ```

### Step 2: Create Release Documentation

1. Create release documentation at `docs/releases/v{version}.md`:
   ```bash
   # Example: docs/releases/v1.2.0.md
   ```
2. Follow the release template format with "Major Changes" and "Fixes" sections
3. Document all new features, fixes, and technical details

### Step 3: Commit and Push to Main

1. Commit all changes including VERSION file and release documentation
2. Push to main branch (or merge PR to main):
   ```bash
   git add VERSION docs/releases/v1.2.0.md
   git commit -m "Release v1.2.0: Brief description"
   git push origin main
   ```

### Step 4: Automatic Release Creation

1. GitHub Actions workflow automatically triggers on push to main
2. Workflow validates the script, environment, and documentation
3. Creates ZIP package and GitHub release with tag
4. **Automatically updates README.md version badge** to reflect new version
5. No manual intervention required

### Step 5: Monitor and Verify

1. Check the "Actions" tab to monitor workflow progress
2. Verify release appears in "Releases" section
3. Download and test the ZIP package

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