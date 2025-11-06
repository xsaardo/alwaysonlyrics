---
description: Clean up unnecessary code, files, and technical debt
---

You are helping clean up the AlwaysOnLyrics codebase. Follow this structured workflow:

## Phase 1: Analysis
1. Analyze the codebase to identify cleanup opportunities:
   - Unused files (check git status for untracked files)
   - Test files in the root directory that should be moved or deleted
   - Commented-out code blocks
   - Unused imports
   - Dead code (unreachable or unused functions/classes)
   - Duplicate code
   - Debug print statements or console.log calls
   - Temporary/scratch files
   - Build artifacts not in .gitignore
   - TODO/FIXME comments that can be addressed

2. Scan key areas:
   - Root directory for misplaced test files
   - Source files for unused imports
   - All Swift files for commented code
   - Check for files not referenced in the Xcode project
   - Look for redundant or obsolete code

## Phase 2: Present Findings
3. Present a comprehensive report of cleanup opportunities:
   - Categorize by type (files, imports, dead code, etc.)
   - For each item, explain why it appears unnecessary
   - Estimate the impact (low/medium/high)
   - Flag any items that might be ambiguous

4. Ask the user to confirm which items should be cleaned up.

## Phase 3: Todo List Creation
5. Use the TodoWrite tool to create a cleanup todo list:
   - Group similar tasks together
   - Order by risk (safest cleanups first)
   - Clear descriptions of what will be removed
   - All tasks starting in "pending" status

## Phase 4: Systematic Cleanup
6. Walk through each cleanup task:
   - Mark current task as "in_progress"
   - Perform the cleanup operation
   - Verify the change doesn't break anything
   - Mark as "completed"
   - Move to next task

7. Safety guidelines during cleanup:
   - Never delete files that are part of the Xcode project without confirmation
   - Keep commented code if it has valuable context
   - Don't remove imports that might be used indirectly
   - Back up ambiguous changes by showing diffs
   - Run builds/tests if significant code is removed

## Phase 5: Summary
8. After cleanup is complete:
   - Summarize what was cleaned up
   - Report how many files/lines were removed
   - Suggest running tests to verify nothing broke
   - Recommend committing the cleanup changes

Keep the codebase healthy by removing clutter while being careful not to break functionality!
