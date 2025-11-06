---
description: Develop frontend/UI changes with design, planning, and step-by-step implementation
---

You are helping develop frontend/UI changes for the AlwaysOnLyrics macOS app. Follow this structured workflow:

## Phase 1: Design Requirements
1. Ask the user detailed questions about the UI/UX changes they want:
   - What UI component or view needs to be changed/created?
   - What should the visual design look like (layout, colors, spacing)?
   - What user interactions are needed (clicks, hovers, keyboard shortcuts)?
   - Should it match existing UI patterns in the app?
   - Are there animations or transitions needed?
   - Should it support dark mode?
   - Any accessibility requirements?
   - Where does this fit in the existing view hierarchy?

## Phase 2: UI Specification
2. Based on the answers, create a detailed UI specification:
   - Visual design description (layout, hierarchy, spacing)
   - Component structure (parent/child views)
   - State management needs (@State, @Published, @Binding)
   - User interactions and event handlers
   - Data flow (how data gets to the view)
   - Styling details (colors, fonts, padding, etc.)
   - Responsive behavior and edge cases
   - Accessibility features (VoiceOver, keyboard navigation)

3. Present the specification to the user and ask for confirmation or adjustments.

## Phase 3: Implementation Planning
4. Once the specification is confirmed, create a detailed plan:
   - Which Views need to be created or modified
   - What ViewModels or @ObservableObject classes are needed
   - State management approach
   - Data binding strategy
   - SwiftUI modifiers and layout containers to use
   - Any custom views or reusable components
   - Order of implementation

## Phase 4: Todo List Creation
5. Use the TodoWrite tool to create a comprehensive todo list with:
   - Specific, actionable UI tasks
   - Clear task descriptions (content and activeForm)
   - Logical ordering (basic layout → styling → interactions → polish)
   - All tasks starting in "pending" status

## Phase 5: Step-by-Step Implementation
6. Walk through each task systematically:
   - Mark current task as "in_progress" before starting
   - Implement the UI component completely
   - Mark as "completed" immediately after finishing
   - Move to the next task
   - Keep the user informed of progress

7. Throughout implementation:
   - Follow SwiftUI best practices and conventions
   - Use proper view composition (small, focused views)
   - Implement proper state management
   - Avoid retain cycles (use [weak self] where needed)
   - Consider performance (avoid unnecessary re-renders)
   - Match existing design system and patterns
   - Ensure dark mode compatibility
   - Add accessibility modifiers (.accessibilityLabel, etc.)
   - Test visual appearance and interactions

8. After all tasks are complete:
   - Summarize what was built
   - Suggest testing the UI in different scenarios
   - Recommend any visual polish or refinements
