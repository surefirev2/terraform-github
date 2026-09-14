# Import existing repository into Terraform state
# Run: terraform import github_repository.repos["ai-blender-workflow"] ai-blender-workflow

import {
  to = github_repository.repos["ai-blender-workflow"]
  id = "ai-blender-workflow"
}
