# Developer Pre-Commit Checklist

**Use this checklist EVERY TIME before committing code.**

---

## ⚡ Quick Checks (Do These First - 2 minutes)

- [ ] **Did I make ONE logical change?** (Not multiple unrelated changes)
- [ ] **Did I test my change locally?** (Manually verified it works)
- [ ] **Does the GUI still launch?** (No new errors on startup)
- [ ] **Can I see the GUI window?** (It displays on screen)

---

## 🔍 Code Quality Checks (5 minutes)

- [ ] **No PowerShell syntax errors** 
  ```powershell
  Invoke-ScriptAnalyzer -Path .\file.ps1 -Severity Error
  ```

- [ ] **No hardcoded paths** (Use relative paths)

- [ ] **No uninitialized variables** (All variables set before use)

- [ ] **No unhandled exceptions** (Wrapped in try-catch)

- [ ] **Error messages are helpful** (Users understand what went wrong)

---

## 🎮 Functional Checks (3 minutes)

- [ ] **Click each modified button** (Does it work? No crash?)

- [ ] **Navigate each tab** (Can I see the content? Does it scroll?)

- [ ] **Try invalid input** (Does it fail gracefully? Or crash?)

- [ ] **Check for console errors** (Any red errors in console? If yes, fix!)

---

## 📝 Documentation Checks (2 minutes)

- [ ] **Updated relevant .md files** (Documentation matches code)

- [ ] **Added comments to complex code** (Others can understand it)

- [ ] **Updated CHANGELOG** (Listed what changed)

- [ ] **No broken links** in documentation

---

## 🚀 Final Checks (1 minute)

- [ ] **Ran PreCommitQA.ps1** (All tests pass)

```powershell
.\TEST\PreCommitQA.ps1
```

- [ ] **No breaking changes** (Existing features still work)

- [ ] **Backward compatible** (Old scripts still work)

- [ ] **Performance acceptable** (No new slowdowns)

---

## ✅ If All Checks Pass

**You are safe to commit!**

```bash
git add .
git commit -m "Brief description of change"
git push origin main
```

---

## ❌ If ANY Check Fails

**DO NOT COMMIT**

1. Stop immediately
2. Fix the issue
3. Retest
4. Go through checklist again
5. Then commit

---

## 🆘 If You're Stuck

**Get help BEFORE committing:**

- [ ] Ask senior developer
- [ ] Review the NEVER_FAIL_AGAIN.md documentation
- [ ] Consult IMPLEMENTATION_REPORT.md
- [ ] Run RUN_ALL_TESTS.ps1
- [ ] **Never commit broken code**

---

## 📊 Time Estimate

- **Quick Checks:** 2 min
- **Code Quality:** 5 min
- **Functional:** 3 min
- **Documentation:** 2 min
- **Final Checks:** 1 min
- **TOTAL:** ~15 minutes per commit

**Time to debug failed production release: 4+ hours**

**Do the 15 minutes. Save the 4 hours.**

---

## 🎯 Remember

```
No commits without testing.
No tests without passing.
No passes without all checks.

✅ Test First, Commit Later.
```

---

**Signature:** Developer Name: _______________  Date: _______________

*By signing this checklist, I confirm that all QA checks have been completed and passed.*
