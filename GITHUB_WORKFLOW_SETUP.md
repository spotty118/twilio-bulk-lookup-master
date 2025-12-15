# GitHub Actions Workflow Setup Instructions

## ⚠️ OAuth Scope Limitation

The GitHub Actions workflow file (`.github/workflows/ci.yml`) could not be pushed directly due to OAuth token scope limitations. You need to add it manually via GitHub's web interface.

## 📋 Steps to Add CI/CD Workflow

### Option 1: Via GitHub Web UI (Recommended)

1. **Navigate to your repository:**
   ```
   https://github.com/spotty118/twilio-bulk-lookup-master
   ```

2. **Go to Actions tab:**
   - Click "Actions" in the top navigation
   - Click "New workflow" or "set up a workflow yourself"

3. **Copy the workflow file:**
   - The workflow content is in your local stash:
     ```bash
     git stash show -p stash@{0} -- .github/workflows/ci.yml
     ```
   - Or get it from the file at: `.github/workflows/ci.yml` (in stash)

4. **Paste and commit:**
   - Paste the YAML content into the editor
   - Name the file: `ci.yml`
   - Commit directly to `main` branch

### Option 2: Retrieve from Local Stash

The workflow file is safely stashed. To retrieve it:

```bash
# View the stashed file
git stash show -p stash@{0} -- .github/workflows/ci.yml

# Or pop it back (creates the file locally)
git stash pop
```

Then manually copy the file content and add it via GitHub UI.

### Option 3: Use GitHub CLI (if installed)

```bash
# Restore from stash
git stash pop

# Use gh CLI to create workflow
gh workflow create ci.yml < .github/workflows/ci.yml
```

## ✅ Verification

Once the workflow is added, you should see:

1. **Workflow file visible** at `https://github.com/spotty118/twilio-bulk-lookup-master/blob/main/.github/workflows/ci.yml`

2. **Actions tab shows workflow** - Visit Actions tab to see CI pipeline status

3. **Automatic runs** - Future commits to `main` will trigger the pipeline automatically

## 📝 Workflow Features

Your CI/CD pipeline includes:

- ✅ **Linting** (RuboCop)
- ✅ **Security Scanning** (Brakeman + Bundle Audit)  
- ✅ **Test Suite** (RSpec with PostgreSQL 16 + Redis 7)
- ✅ **Docker Build** validation
- ✅ **Deploy Ready** notification

## 🐛 Alternative: Update OAuth Token

If you want to push workflows via command line in the future, update your GitHub token with `workflow` scope:

1. Go to https://github.com/settings/tokens
2. Create new token with these scopes:
   - `repo` (all)
   - `workflow` (NEW - required for workflow files)
3. Update your git credentials with the new token

## 📧 Need Help?

If you encounter issues:
- Check the stash has the file: `git stash list`
- Review the file: `git stash show -p stash@{0}`
- Restore if needed: `git stash pop`

The workflow file is 195 lines and includes all CI/CD stages for automated testing, security scanning, and deployment readiness checks.
