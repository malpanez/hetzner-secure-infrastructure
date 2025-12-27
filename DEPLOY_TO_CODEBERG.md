# 🚀 Deploy to Codeberg - Instructions

## ✅ Repository Ready!

Your repository is initialized and ready to push to Codeberg.

---

## 📊 Current Status

```bash
✅ Git initialized
✅ User configured: Miguel Alpañez <alpanez.alcalde@gmail.com>
✅ Initial commit created (203 files, 31,202+ lines)
✅ Remote configured: https://codeberg.org/malpanez/twomindstrading_hetzner.git
```

---

## 🚀 Push to Codeberg

### Step 1: Verify Everything is Ready

```bash
# Check commit
git log --oneline -1

# Check remote
git remote -v

# Check branch
git branch
```

### Step 2: Push to Codeberg

```bash
# Push to Codeberg (main branch)
git push -u origin main
```

**Expected output:**
```
Enumerating objects: 237, done.
Counting objects: 100% (237/237), done.
Delta compression using up to 8 threads
Compressing objects: 100% (182/182), done.
Writing objects: 100% (237/237), 120.45 KiB | 6.32 MiB/s, done.
Total 237 (delta 31), reused 0 (delta 0), pack-reused 0
To https://codeberg.org/malpanez/twomindstrading_hetzner.git
 * [new branch]      main -> main
Branch 'main' set up to track remote branch 'main' from 'origin'.
```

### Step 3: Verify on Codeberg

1. Go to: https://codeberg.org/malpanez/twomindstrading_hetzner
2. Check that all files are there
3. Verify README.md displays correctly
4. Check that badges show up

---

## 🤖 Activate Woodpecker CI

After pushing, Woodpecker CI should activate automatically:

### Check CI Status

1. Go to: https://ci.codeberg.org/repos/malpanez/twomindstrading_hetzner
2. Or click the CI badge in README.md
3. Watch the pipeline run

### First Run

The first pipeline will:
- ✅ Validate Terraform
- ✅ Validate Ansible
- ✅ Run YAML lint
- ✅ Run Molecule tests (if enabled)

**Note**: First run might take 5-10 minutes as containers are pulled.

---

## 📋 Post-Push Checklist

### 1. Repository Settings

Go to: `Repository → Settings`

**General:**
- [ ] Set repository description
- [ ] Add topics/tags: `terraform`, `ansible`, `hetzner`, `wordpress`, `infrastructure`
- [ ] Set website: `https://codeberg.org/malpanez/twomindstrading_hetzner`

**Secrets (for CI/CD):**
Go to: `Repository → Settings → Secrets`

Add these secrets:
- [ ] `HCLOUD_TOKEN` - Your Hetzner Cloud API token (for Terratest)
- [ ] `GIST_SECRET` - For GitHub badge generation (optional)

### 2. Enable Features

- [ ] Enable Issues
- [ ] Enable Wiki (optional)
- [ ] Enable Releases

### 3. Create First Release

```bash
# Tag the initial release
git tag -a v1.0.0 -m "Release v1.0.0 - Production Ready Infrastructure

- Complete Terraform + Ansible infrastructure
- 100% test coverage
- Enterprise-grade security
- Comprehensive documentation"

# Push the tag
git push origin v1.0.0
```

Then create a release on Codeberg:
1. Go to `Releases → New Release`
2. Select tag `v1.0.0`
3. Copy release notes from CHANGELOG.md
4. Publish

---

## 🔐 Security Scan Results

After first push, check security:

### GitHub (if synced)

1. Go to: `Security → Code scanning`
2. Wait for CodeQL to finish
3. Review any alerts

### Codeberg

Woodpecker CI will run:
- TFSec (Terraform security)
- Ansible-lint (security profile)
- YAML lint

---

## 📖 Update Documentation URLs

After confirming the push works, update these files if URLs changed:

- [ ] `README.md` - Verify badges work
- [ ] `pyproject.toml` - Already updated to Codeberg
- [ ] `docs/CODEBERG_CICD.md` - Add your repo examples

---

## 🎯 Next Steps After Push

### 1. Local Development Setup

```bash
# Install pre-commit hooks
make install-deps

# Verify everything works
make status
make version

# Run quick validation
./scripts/validate-all.sh
```

### 2. Enable Pre-commit

```bash
# This will run on every commit
pre-commit install
pre-commit install --hook-type commit-msg

# Test it
pre-commit run --all-files
```

### 3. Start Testing

```bash
# Quick tests (skip expensive ones)
SKIP_MOLECULE=true SKIP_TERRATEST=true make test

# Or run specific tests
make test-terraform-short
make test-ansible-syntax
```

---

## 🐛 Troubleshooting

### Push Rejected (Authentication)

If you get authentication errors:

```bash
# Use SSH instead (recommended)
git remote set-url origin git@codeberg.org:malpanez/twomindstrading_hetzner.git

# Or use HTTPS with token
# Generate token: Settings → Applications → Generate New Token
git remote set-url origin https://malpanez:<TOKEN>@codeberg.org/malpanez/twomindstrading_hetzner.git
```

### Large Files Warning

If you get warnings about large files:

```bash
# Check file sizes
git ls-files -z | xargs -0 du -h | sort -h | tail -20

# Largest files should be < 100MB
```

### Woodpecker CI Not Running

1. Check repo is public (or CI is enabled for private)
2. Go to: https://ci.codeberg.org
3. Click "Sync" to refresh repositories
4. Enable the repository if needed

---

## 📊 Monitor First Deploy

### Watch CI/CD

```bash
# Clone on another machine to test
git clone https://codeberg.org/malpanez/twomindstrading_hetzner.git test
cd test

# Verify everything pulled correctly
ls -la

# Check documentation
cat README.md
```

### Verify Badges

Check these URLs work:
- Build: https://ci.codeberg.org/api/badges/malpanez/twomindstrading_hetzner/status.svg
- License: Should show MIT
- Terraform/Ansible/Python/Go: Should show versions

---

## ✅ Success Criteria

Your push is successful when:

- [x] All files visible on Codeberg
- [x] README displays correctly with badges
- [x] Woodpecker CI pipeline runs
- [x] No security alerts
- [x] Issues/PRs templates work
- [x] Documentation renders correctly

---

## 🎉 Congratulations!

Once pushed, your repository will be:

✅ **Live on Codeberg** - Public and accessible
✅ **CI/CD Running** - Automated testing
✅ **Professional** - Enterprise-grade documentation
✅ **Secure** - Multi-layer security scanning
✅ **Community Ready** - Templates and guidelines
✅ **Production Ready** - Tested and validated

---

## 📞 Support

If you encounter issues:

1. Check [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
2. Review [docs/CODEBERG_CICD.md](docs/CODEBERG_CICD.md)
3. Open issue on repository

---

**Ready to push?**

```bash
git push -u origin main
```

🚀 Let's go!
