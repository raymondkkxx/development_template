@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1
title Git Standard Branch Creation Tool

echo ======================================================
echo       Git Standard Development Branch Creator
echo ======================================================
echo.

:: 1. Check Git Installation
where git >nul 2>&1
if errorlevel 1 goto :ERR_NO_GIT

:: 2. Resolve Default Target Directory (Two levels up from script)
for %%I in ("%~dp0..\..") do (
    set "DEFAULT_DIR=%%~fI"
    set "DEFAULT_PROJ=%%~nxI"
)

:: 3. Directory and Project Selection
echo [1/5] Target Workspace Configuration
echo Default directory : !DEFAULT_DIR!
set "TARGET_DIR="
set /p "TARGET_DIR=Enter base directory path [Press ENTER for default]: "
if "!TARGET_DIR!"=="" set "TARGET_DIR=!DEFAULT_DIR!"
set "TARGET_DIR=!TARGET_DIR:"=!"

echo Default project   : !DEFAULT_PROJ!
set "TARGET_PROJ="
set /p "TARGET_PROJ=Enter project folder name [Press ENTER for default]: "
if "!TARGET_PROJ!"=="" set "TARGET_PROJ=!DEFAULT_PROJ!"
set "TARGET_PROJ=!TARGET_PROJ:"=!"

:: Smart Path Resolution (Avoid duplicate nesting)
set "FULL_PATH=!TARGET_DIR!\!TARGET_PROJ!"
if not exist "!FULL_PATH!" (
    for %%P in ("!TARGET_DIR!") do set "CUR_FOLDER=%%~nxP"
    if /i "!CUR_FOLDER!"=="!TARGET_PROJ!" (
        set "FULL_PATH=!TARGET_DIR!"
    ) else if exist "!TARGET_DIR!\.git" (
        set "FULL_PATH=!TARGET_DIR!"
    )
)

if not exist "!FULL_PATH!" goto :ERR_NO_DIR

cd /d "!FULL_PATH!" || goto :ERR_ACCESS_DIR

git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 goto :ERR_NOT_GIT

:: 4. Display Current Version Information
echo.
echo ======================================================
for /f "delims=" %%B in ('git branch --show-current 2^>nul') do set "CURR_BRANCH=%%B"
if "!CURR_BRANCH!"=="" set "CURR_BRANCH=(Detached HEAD)"
echo Active Project : !FULL_PATH!
echo Current Branch : !CURR_BRANCH!
echo Base Commit    : 
git log -1 --pretty=format:"  Commit: %%h - %%s (by %%an, %%ar)"
echo.
echo ======================================================
echo.

:: 5. Standard Branch Naming
:PROMPT_BRANCH_TYPE
echo [2/5] Select Standard Branch Type:
echo   [1] feature/  (New features or business requirements)
echo   [2] bugfix/   (Standard defect / bug fixing)
echo   [3] hotfix/   (Critical urgent production patch)
echo   [4] refactor/ (Code refactoring / architecture optimization)
echo   [5] test/     (Test automation / experimental branch)
echo   [6] Custom    (No prefix / fully manual name)
set "TYPE_CHOICE="
set /p "TYPE_CHOICE=Select prefix option [1-6] (Default: 1): "
if "!TYPE_CHOICE!"=="" set "TYPE_CHOICE=1"

set "PREFIX=feature/"
if "!TYPE_CHOICE!"=="2" set "PREFIX=bugfix/"
if "!TYPE_CHOICE!"=="3" set "PREFIX=hotfix/"
if "!TYPE_CHOICE!"=="4" set "PREFIX=refactor/"
if "!TYPE_CHOICE!"=="5" set "PREFIX=test/"
if "!TYPE_CHOICE!"=="6" set "PREFIX="

:PROMPT_BRANCH_DESC
echo.
echo [3/5] Branch Identifier / Description:
set "BRANCH_DESC="
set /p "BRANCH_DESC=Enter branch description (e.g. auth-token-v2 / fix-login-crash): "
if "!BRANCH_DESC!"=="" set "BRANCH_DESC=dev-patch"

:: Sanitize branch name: replace spaces with hyphens, remove quotes
set "BRANCH_DESC=!BRANCH_DESC:"=!"
set "BRANCH_DESC=!BRANCH_DESC: =-!"

set "NEW_BRANCH=!PREFIX!!BRANCH_DESC!"

:: Check if branch already exists locally
git rev-parse --verify "!NEW_BRANCH!" >nul 2>&1
if not errorlevel 1 (
    echo.
    echo [WARNING] Branch '!NEW_BRANCH!' already exists locally!
    echo   [1] Choose another branch name (Default)
    echo   [2] Switch directly to existing '!NEW_BRANCH!'
    set "EXIST_CHOICE="
    set /p "EXIST_CHOICE=Select option [1/2] (Default: 1): "
    if "!EXIST_CHOICE!"=="2" (
        git checkout "!NEW_BRANCH!"
        goto :BRANCH_CHECKOUT_DONE
    )
    goto :PROMPT_BRANCH_DESC
)

:: Create and switch to new branch from current commit
echo.
echo Creating and switching to branch '!NEW_BRANCH!'...
git checkout -b "!NEW_BRANCH!"
if errorlevel 1 goto :ERR_BRANCH_CREATE

:BRANCH_CHECKOUT_DONE
echo.
echo ======================================================
echo [OK] Successfully switched to branch: !NEW_BRANCH!
echo ======================================================

:: 6. Commit Message & Working Tree Handling
echo.
echo [4/5] Commit Message Configuration
set "DEFAULT_COMMIT=!PREFIX!!BRANCH_DESC!: initialize development branch"
echo Default Commit Message: "!DEFAULT_COMMIT!"
set "COMMIT_MSG="
set /p "COMMIT_MSG=Enter commit message (Press ENTER for default): "
if "!COMMIT_MSG!"=="" set "COMMIT_MSG=!DEFAULT_COMMIT!"
set "COMMIT_MSG=!COMMIT_MSG:"=!"

:: Check for uncommitted changes in working directory
set "HAS_UNCOMMITTED=0"
for /f "delims=" %%S in ('git status --porcelain 2^>nul') do set "HAS_UNCOMMITTED=1"

if "!HAS_UNCOMMITTED!"=="1" (
    echo.
    echo [NOTICE] Uncommitted local modifications detected.
    set /p "DO_COMMIT=Stage and commit these changes now? [Y/N] (Default: Y): "
    if /i not "!DO_COMMIT!"=="N" (
        echo Staging all changes...
        git add -A
        git commit -m "!COMMIT_MSG!"
        echo [OK] Changes committed.
    )
) else (
    echo.
    echo Local working tree is clean. No uncommitted modifications.
)

:: 7. Remote Push Option
echo.
echo [5/5] Remote Synchronization
set "PUSH_CHOICE="
set /p "PUSH_CHOICE=Publish and push '!NEW_BRANCH!' to remote origin? [Y/N] (Default: N): "
if /i "!PUSH_CHOICE!"=="Y" (
    echo Pushing new branch to origin...
    git push -u origin "!NEW_BRANCH!"
    if errorlevel 1 (
        echo [WARNING] Failed to push to remote. Please verify remote repository connectivity.
    ) else (
        echo [OK] Remote branch created and tracking established.
    )
)

echo.
echo ======================================================
echo [SUCCESS] Branch ready for development!
echo Active Branch : !NEW_BRANCH!
echo Latest Commit :
git log -1 --oneline
echo ======================================================
goto :FINISH

:: --- Error Handlers ---

:ERR_NO_GIT
echo [ERROR] Git command not found. Please ensure Git is installed and in PATH.
goto :FINISH

:ERR_NO_DIR
echo.
echo [ERROR] Target directory not found: !FULL_PATH!
goto :FINISH

:ERR_ACCESS_DIR
echo.
echo [ERROR] Unable to access target directory: !FULL_PATH!
goto :FINISH

:ERR_NOT_GIT
echo.
echo [ERROR] The directory is not a valid Git repository: !FULL_PATH!
goto :FINISH

:ERR_BRANCH_CREATE
echo.
echo [ERROR] Failed to create branch '!NEW_BRANCH!'. Check Git status.
goto :FINISH

:FINISH
echo.
pause