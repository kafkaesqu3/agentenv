The purpose of this repository is to act as the golden image agent harness environment, of which all other agent environments will derive from. 
This repository is responsible for the following: 

- installation of existing harness frameworks (currently supported: claude code, codex, opencode)
- installation of system tools and utilities needed
- configuration of existing harnesses to the our standards (environments, hooks, core plugins/skills)
- maintenance of Docker images of the environment
- caller script to spawn the agent in containers or sandboxes

Future harnesses (software development, reverse engineering, CUA, web browsing/scraping, system maintenance, data analysis, etc) will all share this project, so any change we make to this project MUST be applicable to all of the above tasks. Any hooks, skills, or instructions placed in this repository MUST be relevant to all agent use cases. 

