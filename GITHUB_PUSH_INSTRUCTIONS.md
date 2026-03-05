# GitHub Push Instructions

## Current Situation

There are nested git repositories:
- `backend/.git` - Git initialized in backend folder
- Need to push entire project to: https://github.com/AkshataUdyawar91/FAPApplication.git

## Option 1: Push from Root (Recommended)

Run these commands from the root `FAPLatest` directory:

```bash
# Remove nested git folders
Remove-Item -Path "backend\.git" -Recurse -Force
Remove-Item -Path "backend\.git" -Recurse -Force
Remove-Item -Path "frontend\.git" -Recurse -Force -ErrorAction SilentlyContinue

# Initialize git in root
git init

# Configure git
git config user.name "Akshata Udyawar"
git config user.email "audyawar@deloitte.com"

# Add remote
git remote add origin https://github.com/AkshataUdyawar91/FAPApplication.git

# Add all files
git add .

# Commit
git commit -m "Initial commit: Bajaj Document Processing System

- Complete .NET 8 backend with Clean Architecture
- Flutter frontend with document upload
- Multi-agent AI system with Azure OpenAI
- JWT authentication and role-based access
- Database with EF Core migrations
- Comprehensive documentation"

# Push to main branch
git branch -M main
git push -u origin main --force
```

## Option 2: Push Backend Only

If you want to push just the backend first:

```bash
cd backend

# Configure git (if not already done)
git config user.name "Akshata Udyawar"
git config user.email "audyawar@deloitte.com"

# Add remote
git remote add origin https://github.com/AkshataUdyawar91/FAPApplication.git

# Add all files
git add .

# Commit
git commit -m "Backend: .NET 8 API with AI agents"

# Push
git branch -M main
git push -u origin main --force
```

## Important Notes

### Before Pushing

1. **Verify .gitignore** - Check that sensitive files are excluded:
   - `appsettings.Development.json` (contains Azure API keys)
   - `bin/` and `obj/` folders
   - `.dart_tool/` and `build/` folders

2. **Use Template File** - The repository includes `appsettings.Development.TEMPLATE.json` with placeholders for sensitive data

3. **Check File Size** - Large files (>100MB) will be rejected by GitHub

### After Pushing

1. **Clone and Test** - Clone the repository to verify everything works:
   ```bash
   git clone https://github.com/AkshataUdyawar91/FAPApplication.git
   cd FAPApplication
   ```

2. **Setup Instructions** - Follow README.md to set up the project

3. **Add Secrets** - Create your own `appsettings.Development.json` from the template

## Troubleshooting

### If you get "remote already exists"
```bash
git remote remove origin
git remote add origin https://github.com/AkshataUdyawar91/FAPApplication.git
```

### If you get authentication errors
You may need to use a Personal Access Token (PAT) instead of password:
1. Go to GitHub Settings → Developer settings → Personal access tokens
2. Generate new token with `repo` scope
3. Use token as password when pushing

### If you want to see what will be committed
```bash
git status
git diff --cached
```

## What Will Be Pushed

### Backend
- Complete .NET 8 Web API
- All AI agents and services
- Database migrations
- Unit and property-based tests
- Configuration files (template only)

### Frontend
- Flutter application
- All feature modules
- UI components
- State management setup

### Documentation
- README.md
- Application summary
- Deployment guides
- API documentation
- Login credentials guide

### Excluded (via .gitignore)
- Build artifacts (bin/, obj/, build/)
- IDE files (.vs/, .idea/)
- Sensitive configuration files
- Generated files (*.g.dart)
- Node modules and packages

## Current Git Status

Run `git status` to see what files will be committed.

## Need Help?

If you encounter issues, you can:
1. Check git configuration: `git config --list`
2. View remote: `git remote -v`
3. Check branch: `git branch`
4. View commit history: `git log`
