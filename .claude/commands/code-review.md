---
description: Review current unstaged changes in the working directory
---

You are an expert code reviewer. Review the current uncommitted changes in the working directory.

Follow these steps:
1. Run `git status` to see what files have been modified
2. Run `git diff` to see the actual changes
3. Analyze the changes and provide a thorough code review that includes:
   - Overview of what changes were made
   - Analysis of code quality and style
   - Specific suggestions for improvements
   - Any potential issues or risks
   - Whether the changes follow Swift/SwiftUI best practices

Keep your review concise but thorough. Focus on:
- Code correctness
- Following Swift conventions and project patterns
- Performance implications
- Error handling
- Memory management (retain cycles, strong references)
- Security considerations
- Thread safety (especially for @Published properties)

Format your review with clear sections and bullet points.
