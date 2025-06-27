# Environment Configuration

This file contains environment-specific configuration data for the ProPresenter OneDrive Setup Assistant.

## Microsoft 365 Tenant Configuration

### Primary Tenant

- **Tenant ID**: `b3873e62-b4ee-47e8-bb4d-e5ef560964af`
- **Tenant Domain**: `mosaikkircheberlin.onmicrosoft.com`
- **User Email Domain**: `@mosaikberlin.com`
- **SharePoint Base URL**: `https://mosaikkircheberlin.sharepoint.com/`

### User Types

- **Primary Users**: `@mosaikberlin.com` email addresses
- **Guest Users**: External email addresses (gmail, hotmail, etc.) with access to Teams

## SharePoint Configuration

### ProPresenter Document Library

- **SharePoint URL**: `https://mosaikkircheberlin.sharepoint.com/sites/VisualsTeam/Freigegebene%20Dokumente/Forms/AllItems.aspx?id=/sites/VisualsTeam/Freigegebene%20Dokumente/ProPresenter&viewid=aeb6fedf-4966-4cf5-b92e-70a714ba87dc`
- **Site Path**: `/sites/VisualsTeam`
- **Library Path**: `/Freigegebene Dokumente/ProPresenter`

### Expected Folder Structure

```text
ProPresenter/
├── Application Directory/
├── Long-living Assets/
└── Short-living Assets/
```

## Validation Requirements

### Tenant Validation

- Users must have access to tenant ID: `b3873e62-b4ee-47e8-bb4d-e5ef560964af`
- Support both `@mosaikberlin.com` users and guest users

### Access Validation

- Verify user has access to ProPresenter Teams channel
- Confirm access to SharePoint site: `/sites/VisualsTeam`
- Validate permissions to ProPresenter document library

## Placeholders for Future Configuration

### ProPresenter Configuration

- **Target ProPresenter Version**: `7.12`
- **Installation Method**: Homebrew package manager
- **ProPresenter Application Path**: `/Applications/ProPresenter.app`
- **Configuration File**: `~/Library/Preferences/com.renewedvision.propresenter.plist`
- **Key Setting**: `applicationShowDirectory`
- **Target Configuration Path**: `~/ProPresenter-Sync/Application-Directory`

## Script Distribution Configuration

### GitHub Repository

- **Repository**: `mosaikberlin/propresenter-setup-assistant`
- **GitHub API URL**: `https://api.github.com/repos/mosaikberlin/propresenter-setup-assistant/releases/latest`
- **Release Distribution**: ZIP packages with complete script suite
- **Main Script File**: `ProPresenter-Setup-Assistant.command`

### Auto-Update Configuration

- **Update Check Method**: GitHub Releases API
- **Version Comparison**: Semantic versioning
- **Download Method**: GitHub release asset download
- **Restart Method**: Execute updated script after successful download

### ProPresenter Installation Source

- **Homebrew Package**: `propresenter` (if available)
- **Alternative Source**: Direct download from Renewed Vision
- **Version Verification**: Check CFBundleShortVersionString in Info.plist

## Folder Mapping Configuration

### OneDrive to Symlink Mapping

```text
OneDrive Source → Symlink Target
────────────────────────────────────────────────────────────
ProPresenter/Application Directory/ → ~/ProPresenter-Sync/Application-Directory/
ProPresenter/Long-living Assets/ → ~/ProPresenter-Sync/Long-living-Assets/
ProPresenter/Short-living Assets/ → ~/ProPresenter-Sync/Short-living-Assets/
```
