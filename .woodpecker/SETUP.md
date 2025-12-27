# Woodpecker CI Setup Guide for Codeberg

## 🎯 Quick Start

Woodpecker CI is Codeberg's native CI/CD platform. Follow these steps to enable it for your repository.

---

## 📋 Prerequisites

- Repository hosted on Codeberg
- Repository owner or admin access
- `.woodpecker/test.yml` pipeline file in repository (✅ already created)

---

## 🚀 Enabling Woodpecker CI

### Step 1: Access Woodpecker CI

1. Go to [https://ci.codeberg.org](https://ci.codeberg.org)
2. Click **"Login"** in the top-right corner
3. Authorize with your Codeberg account

### Step 2: Activate Your Repository

1. Once logged in, you'll see **"Repositories"** in the sidebar
2. Click **"+ New Repository"** or **"Enable Repository"**
3. Find `malpanez/twomindstrading_hetzner` in the list
4. Click the **"Enable"** or **"Activate"** toggle next to it

### Step 3: Grant Permissions

Woodpecker needs these permissions:
- ✅ **Read repository** - To clone the code
- ✅ **Read repository metadata** - To detect branches and commits
- ✅ **Write commit status** - To show build status on commits

Click **"Allow"** or **"Grant"** when prompted.

### Step 4: Trigger First Build

Option A: **Push a commit**
```bash
git commit --allow-empty -m "trigger: Initial Woodpecker CI build"
git push origin main
```

Option B: **Manual trigger**
1. Go to your repository in Woodpecker CI
2. Click **"Restart"** on the latest commit

---

## 🔍 Viewing Build Results

### In Woodpecker CI Dashboard

1. Go to [https://ci.codeberg.org](https://ci.codeberg.org)
2. Click **"Repositories"** → **"twomindstrading_hetzner"**
3. You'll see:
   - ✅ **Builds** - List of all pipeline runs
   - 📊 **Status** - Success/Failure/Pending
   - 📝 **Logs** - Detailed output for each step

### In Codeberg Repository

1. Go to your repository on Codeberg
2. Look for commit status badges next to commits:
   - ✅ Green checkmark = Build passed
   - ❌ Red X = Build failed
   - 🟡 Yellow dot = Build pending

---

## 📊 Pipeline Stages (What You Should See)

When Woodpecker CI runs `.woodpecker/test.yml`, you should see these stages:

### 1. **validate-terraform** (~2 minutes)
```
✅ Terraform Format Check
✅ Terraform Init
✅ Terraform Validate
```

### 2. **validate-ansible-syntax** (~1 minute)
```
✅ Ansible Syntax Check
```

### 3. **validate-ansible-lint** (~2 minutes)
```
✅ Ansible Lint Check
✅ YAML Lint Check
```

### 4. **test-molecule** (~15 minutes)
```
✅ Molecule Test: nginx-wordpress
✅ Molecule Test: valkey
✅ Molecule Test: mariadb
... (12 roles total)
```

### 5. **security-scan** (~2 minutes)
```
✅ Trivy Vulnerability Scan
```

### 6. **docs-check** (~1 minute)
```
✅ Verify Required Docs Exist
```

**Total Duration**: ~20-25 minutes

---

## 🐛 Troubleshooting

### Issue 1: "Repository not showing up in Woodpecker"

**Problem**: Can't find repository in the activation list.

**Solution**:
1. Ensure repository exists on Codeberg
2. Log out of Woodpecker CI and log back in
3. Check repository is public or you have access
4. Refresh the repository list

### Issue 2: "Build not triggering on push"

**Problem**: Pushed commits but no build starts.

**Solution**:
1. Check webhook is created:
   - Go to Codeberg → Repository Settings → Webhooks
   - Should see a webhook pointing to `ci.codeberg.org`
2. If missing, disable and re-enable repository in Woodpecker
3. Verify `.woodpecker/test.yml` exists in repository root

### Issue 3: "Docker permission denied"

**Problem**: Molecule tests fail with Docker socket permission errors.

**Current Status**: `.woodpecker/test.yml` already has this fix:
```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

If still failing, check Woodpecker CI runner has Docker access.

### Issue 4: "No logs visible"

**Problem**: Build runs but no output shown.

**Solution**:
1. Wait for build to complete (can take 20+ minutes)
2. Click on individual pipeline steps to see detailed logs
3. Check browser console for JavaScript errors
4. Try different browser

### Issue 5: "Badge not showing in README"

**Problem**: Build status badge shows "unknown" or doesn't load.

**Current Badge URL**:
```markdown
[![Build Status](https://ci.codeberg.org/api/badges/malpanez/twomindstrading_hetzner/status.svg)](https://ci.codeberg.org/malpanez/twomindstrading_hetzner)
```

**Solution**:
1. Ensure at least one build has completed
2. Verify repository name matches exactly
3. Badge updates after each build (may be cached)

---

## 🔧 Configuration Files

### Pipeline File: `.woodpecker/test.yml`

**Location**: `/home/malpanez/repos/hetzner-secure-infrastructure/.woodpecker/test.yml`

**Key Points**:
- Uses Docker images for isolated environments
- Mounts Docker socket for Molecule tests
- Runs in parallel where possible
- Validates before testing (fail-fast)

### Linting Configs

These control what gets validated:

- **`.yamllint.yml`** - YAML syntax rules
- **`.ansible-lint`** - Ansible best practices
- **`.markdownlint.json`** - Markdown formatting
- **`.tflint.hcl`** - Terraform linting

---

## 📈 Expected First Build

### Timeline

```
00:00 - Build triggered
00:01 - Clone repository
00:02 - Start validate-terraform
00:04 - Start validate-ansible-syntax
00:05 - Start validate-ansible-lint
00:07 - Start test-molecule (longest step)
00:22 - Start security-scan
00:24 - Start docs-check
00:25 - Build complete ✅
```

### If All Tests Pass

You'll see:
```
✅ validate-terraform      (2m 15s)
✅ validate-ansible-syntax (1m 05s)
✅ validate-ansible-lint   (2m 30s)
✅ test-molecule           (15m 20s)
✅ security-scan           (2m 10s)
✅ docs-check              (45s)

Total: 24m 05s
BUILD SUCCESSFUL
```

### If Tests Fail

Click on the failed step to see:
- ❌ Which command failed
- 📝 Full error output
- 🔍 File and line number (for syntax errors)

---

## 🎯 Next Steps After Setup

Once Woodpecker CI is working:

1. **Add badge to README** (already included):
   ```markdown
   [![Build Status](https://ci.codeberg.org/api/badges/malpanez/twomindstrading_hetzner/status.svg)]
   ```

2. **Set up protected branches**:
   - Codeberg → Repository Settings → Branches
   - Protect `main` branch
   - Require CI to pass before merge

3. **Configure notifications** (optional):
   - Woodpecker → Repository Settings → Notifications
   - Email on build failures

4. **Review logs regularly**:
   - Check for security vulnerabilities
   - Monitor test execution times
   - Address warnings before they become errors

---

## 📚 Additional Resources

- [Woodpecker CI Documentation](https://woodpecker-ci.org/docs/intro)
- [Codeberg CI Help](https://docs.codeberg.org/ci/)
- [Forgejo Actions](https://forgejo.org/docs/latest/user/actions/) (alternative to Woodpecker)

---

## 🆘 Still Not Working?

If you still can't see Woodpecker CI working:

1. **Check Codeberg Status**:
   - [https://status.codeberg.org](https://status.codeberg.org)
   - CI infrastructure may be down

2. **Try Local Testing**:
   ```bash
   # Verify pipeline locally before pushing
   make validate
   make test-ansible
   ```

3. **Consider GitHub Actions Alternative**:
   - `.github/workflows/ci.yml` already configured
   - Mirror repository to GitHub as backup CI

4. **Contact Codeberg Support**:
   - [https://codeberg.org/Codeberg/Community/issues](https://codeberg.org/Codeberg/Community/issues)
   - Active community support

---

**Last Updated**: 2025-12-26
**Status**: ✅ Configuration files ready, activation required
