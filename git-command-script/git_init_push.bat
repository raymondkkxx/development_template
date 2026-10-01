@echo off
setlocal EnableExtensions EnableDelayedExpansion
title GitHub Auto Create and Push Utility
chcp 65001 >nul 2>&1

:: 1. Resolve Default Target Directory (Parent directory of script)
for %%I in ("%~dp0..") do set "DEFAULT_DIR=%%~fI"

echo ======================================================
echo     GitHub Auto Remote Creation and Push Utility
echo ======================================================
echo.

:: 2. Prerequisite Checks
where git >nul 2>&1
if errorlevel 1 goto :ERR_NO_GIT

where gh >nul 2>&1
if errorlevel 1 goto :ERR_NO_GH

:: Verify GitHub CLI Login Status
gh auth status >nul 2>&1
if errorlevel 1 goto :ERR_GH_AUTH

:: 3. Target Directory Selection
echo [Directory Selection]
echo Default target: %DEFAULT_DIR%
set "TARGET_DIR="
set /p "TARGET_DIR=Enter target directory (Press ENTER for default): "

if not defined TARGET_DIR set "TARGET_DIR=%DEFAULT_DIR%"
set "TARGET_DIR=%TARGET_DIR:"=%"
for %%I in ("%TARGET_DIR%") do set "TARGET_DIR=%%~fI"

if not exist "%TARGET_DIR%" goto :PROMPT_MKDIR
goto :NAVIGATE

:PROMPT_MKDIR
echo.
echo Target path does not exist: %TARGET_DIR%
set /p "MKDIR_CONFIRM=Create this directory now? [Y/N] (Default: Y): "
if /i "%MKDIR_CONFIRM%"=="N" goto :CANCEL_EXIT
mkdir "%TARGET_DIR%" 2>nul
if errorlevel 1 goto :ERR_MKDIR

:NAVIGATE
pushd "%TARGET_DIR%"
if errorlevel 1 goto :ERR_PUSHD

:: Extract folder name as default repository name
for %%I in ("%CD%") do set "DEFAULT_REPO_NAME=%%~nxI"

echo.
echo Active Directory: %CD%
echo ======================================================
echo.

:: 4. Repository Configurations
echo [GitHub Remote Setup]
echo Default repository name: %DEFAULT_REPO_NAME%
set "REPO_NAME="
set /p "REPO_NAME=Enter repository name (Press ENTER for default): "
if not defined REPO_NAME set "REPO_NAME=%DEFAULT_REPO_NAME%"
set "REPO_NAME=%REPO_NAME:"=%"

:: Visibility Selection
set "VISIBILITY=public"
set /p "VIS_INPUT=Make repository private? [Y/N] (Default: N): "
if /i "%VIS_INPUT%"=="Y" set "VISIBILITY=private"

:: Commit Message
set "COMMIT_MSG="
set /p "COMMIT_MSG=Enter commit message (Press ENTER for 'Initial commit'): "
if not defined COMMIT_MSG set "COMMIT_MSG=Initial commit"

:: 5. Git Local Operations
echo.
echo [1/3] Preparing local repository...
if not exist ".git" (
    git init
    if errorlevel 1 goto :ERR_GIT_INIT
)
git branch -M main >nul 2>&1

git add -A
if errorlevel 1 goto :ERR_GIT_ADD

git diff --cached --quiet
if errorlevel 1 (
    git commit -m "%COMMIT_MSG%"
    if errorlevel 1 goto :ERR_GIT_COMMIT
)

:: 6. Create Remote Repository and Push via GitHub CLI
echo.
echo [2/3] Creating '%REPO_NAME%' on GitHub as %VISIBILITY%...
echo [3/3] Uploading code to GitHub...

gh repo create "%REPO_NAME%" --%VISIBILITY% --source="." --remote=origin --push
if errorlevel 1 goto :ERR_GH_CREATE

echo.
echo ======================================================
echo [SUCCESS] Repository created on GitHub and uploaded!
echo ======================================================
goto :FINISH

:: --- Error Handlers ---

:ERR_NO_GIT
echo [ERROR] Git is not installed or not in PATH.
echo Install from: https://git-scm.com/
goto :SCRIPT_FAIL

:ERR_NO_GH
echo [ERROR] GitHub CLI ('gh') is not installed.
echo To allow automatic cloud repository creation, install it via:
echo   winget install --id GitHub.cli
echo After installing, run 'gh auth login' once in your terminal.
goto :SCRIPT_FAIL

:ERR_GH_AUTH
echo [ERROR] GitHub CLI is not authenticated.
echo Please run 'gh auth login' in terminal to log in to your account.
goto :SCRIPT_FAIL

:ERR_MKDIR
echo [ERROR] Failed to create directory: %TARGET_DIR%
goto :SCRIPT_FAIL

:ERR_PUSHD
echo [ERROR] Failed to navigate to directory: %TARGET_DIR%
goto :SCRIPT_FAIL

:ERR_GIT_INIT
echo [ERROR] Local 'git init' failed.
goto :SCRIPT_FAIL

:ERR_GIT_ADD
echo [ERROR] 'git add' failed.
goto :SCRIPT_FAIL

:ERR_GIT_COMMIT
echo [ERROR] Commit failed. Configure git user name and email first:
echo   git config --global user.name "Your Name"
echo   git config --global user.email "you@example.com"
goto :SCRIPT_FAIL

:ERR_GH_CREATE
echo.
echo ======================================================
echo [ERROR] Failed to create or push repository on GitHub.
echo Checklist:
echo 1. Does a repository named '%REPO_NAME%' already exist in your account?
echo 2. Check network connectivity to github.com.
echo ======================================================
goto :SCRIPT_FAIL

:CANCEL_EXIT
echo Operation cancelled.
goto :FINISH

:SCRIPT_FAIL
echo.
echo Execution terminated.

:FINISH
popd 2>nul
echo.
echo Press any key to exit...
pause >nul
endlocal