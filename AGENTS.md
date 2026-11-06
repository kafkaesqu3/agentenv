The purpose of this repository is to act as the golden image agent harness environment, of which all other agent environments will derive from. 
This repository is responsible for the following: 

- installation of existing harness frameworks (currently supported: claude code, codex, opencode)
- installation of system tools and utilities needed
- configuration of existing harnesses to the our standards (environments, hooks, core plugins/skills)
- maintenance of Docker images of the environment
- caller script to spawn the agent in containers or sandboxes

Future harnesses (software development, reverse engineering, CUA, web browsing/scraping, system maintenance, data analysis, etc) will all share this project, so any change we make to this project MUST be applicable to all of the above tasks. Any hooks, skills, or instructions placed in this repository MUST be relevant to all agent use cases. 

When finished, commit verified changes belonging to the task without asking for
separate confirmation. Leave unrelated user changes untouched, do not create empty
commits, and do not push unless requested. Report the commit hash or any blocker.

INSTRUCTIONS
- I'll give you instructions on how i want my agents to look, and you update the configuration of the agent installed by this project, agentenv. 

RULES: 
- Configs need to be kept as standard as possible. CLAUDE.md should refer to AGENTS.md. 
- Startup needs to be kept as fast as possible. Keep config changes that rely on external request done on build-time, so that run-time is quick to launch without having to wait for things to build or be fetched. 
- You should avoid leaving work uncommitted in git repositories. When you're done with a concrete task, you should commit it with a commit message
- Create PRs when finishing a branch