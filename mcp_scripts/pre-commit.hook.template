#!/bin/sh
# Git pre-commit hook to run pre-commit checks

make run-pre-commit
RESULT=$?
if [ $RESULT -ne 0 ]; then
  echo "Pre-commit checks failed. Commit aborted."
  exit 1
fi

exit 0
