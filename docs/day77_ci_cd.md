

\# QueryForge Day 77 — GitHub Actions CI and Deployment Readiness



\## What is delivered



\- GitHub Actions workflow at `.github/workflows/queryforge-ci.yml`.

\- Runs on pushes to `main`, pull requests targeting `main`, or manual dispatch.

\- Uses Python 3.12 and 3.13 with offline pytest regression tests.

\- Compiles key modules, records JUnit XML, and publishes test-result artifacts.

\- Restricts GitHub token permissions to read-only repository contents.

\- Does not connect to the project PostgreSQL instance or run ETL writes.

\- Does not deploy to a production server, configure secrets, or push images.



\## Run locally



From `D:\\QueryForge` using PowerShell:



```powershell

py -m pytest -q .\\sql\\practice\\test\_day77\_ci\_workflow.py

```



Use the full Day 77 PowerShell validation block to test all historical files and commit only the four Day 77 artifacts.



\## Verify on GitHub



1\. Push the four Day 77 files to `main`.

2\. Open the GitHub repository's \*\*Actions\*\* tab.

3\. Select \*\*QueryForge Offline CI\*\*.

4\. Confirm the most recent workflow run has a green result on Python 3.12 and 3.13.

5\. If a job fails, inspect the failing step and adjust dependencies or code in a separate reviewed commit.



\## Production deployment: not yet enabled



CI only proves repeatable automated offline testing. Database deployment, live credentials, environment approvals, rollback procedures, and safe secret management must be explicitly designed before a CD deployment workflow can be enabled. No automated production deployment is configured by this day.



\## Status



Day 77 configuration and local checks: pending until the PowerShell verification succeeds.



GitHub-hosted Actions results: pending until the run is verified in the Actions tab.
