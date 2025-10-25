# Nexa Project - AI Assistant Instructions

## Automatic Agent Routing

**CRITICAL INSTRUCTION**: For EVERY user request, you MUST follow this workflow:

1. **Analyze the Request**: Determine if the request requires specialized agent expertise
2. **Invoke task-router Agent**: Use the task-router agent to analyze the request and determine which specialized agent(s) should handle it
3. **Execute Recommendation**: Follow the task-router's recommendation and invoke the appropriate specialized agent(s)

### When to Use Agents

**Always use agents for:**
- Backend API development (node-express-backend)
- Flutter UI components (nexa-flutter-ui)
- API contract validation (api-contract-validator)
- Test architecture design (flutter-backend-test-architect)
- CI/CD pipeline work (flutter-express-cicd)
- Request analysis and routing (task-router)

**Only handle directly without agents:**
- Simple questions about the codebase
- Clarification questions to the user
- Reading/showing existing code
- Quick explanations

### Agent Invocation Protocol

1. **First**: Launch task-router to analyze request
   ```
   Task(subagent_type: "task-router", ...)
   ```

2. **Then**: Follow task-router's recommendation to invoke specialized agents

3. **Finally**: Summarize agent outputs for the user

### Example Workflows

**User Request**: "Add a new API endpoint for user authentication"

**Your Response**:
1. "Let me use the task-router agent to analyze this request..."
2. [Invoke task-router]
3. [Task-router recommends: node-express-backend → api-contract-validator → flutter-backend-test-architect]
4. [Invoke node-express-backend agent]
5. [Summarize backend implementation]
6. [Invoke api-contract-validator agent]
7. [Summarize validation results]
8. [Invoke flutter-backend-test-architect agent]
9. [Summarize test design]

**User Request**: "Create a new Flutter widget for displaying user profiles"

**Your Response**:
1. "I'll route this through the task-router..."
2. [Invoke task-router]
3. [Task-router recommends: nexa-flutter-ui]
4. [Invoke nexa-flutter-ui agent]
5. [Present widget implementation to user]

**User Request**: "Fix the navigation bug on web"

**Your Response**:
1. "Let me analyze this with the task-router..."
2. [Invoke task-router]
3. [Task-router might recommend: nexa-flutter-ui for investigation and fix]
4. [Invoke recommended agent]
5. [Present solution]

## Project Context

### Tech Stack
- **Backend**: Node.js, Express, MongoDB, Mongoose, Zod validation
- **Frontend**: Flutter, Dart, Riverpod state management, go_router navigation
- **Mobile**: iOS, Android, Web (responsive design)
- **Authentication**: OAuth 2.0 (Google, Apple Sign-In)
- **Real-time**: Socket.io for chat and notifications

### Architecture Patterns
- **Backend**: Routes → Controllers → Services → Models (clean separation)
- **Frontend**: Feature-first architecture with Riverpod providers
- **API**: RESTful with OpenAPI 3.0 specifications
- **State**: Riverpod for Flutter state management

### Code Quality Standards
- **Backend**: OpenAPI specs, Zod validation, Jest/Vitest tests
- **Frontend**: Widget tests, integration tests, null safety
- **Both**: Type safety, comprehensive error handling, proper documentation

## Agent Availability

Your specialized agents:
- **task-router**: Request analysis and agent routing
- **node-express-backend**: Backend API development
- **nexa-flutter-ui**: Flutter UI components
- **api-contract-validator**: API contract consistency
- **flutter-backend-test-architect**: Test design
- **flutter-express-cicd**: CI/CD pipelines

## Critical Rules

1. ✅ **ALWAYS** use task-router as the first step for user requests
2. ✅ **ALWAYS** invoke specialized agents for their domains
3. ✅ **NEVER** skip agent invocation for specialized tasks
4. ✅ **ALWAYS** summarize agent outputs for the user
5. ✅ **ALWAYS** follow agent recommendations from task-router

## Exception Cases

**Only bypass agents for:**
- Questions about agent system itself
- Simple file reading requests
- Quick code explanations
- Clarifying user requirements before routing

---

**Remember**: The agent system is your primary way of providing high-quality, specialized assistance. Use it proactively for every substantive request!
