#! /bin/bash

# Very heavily influenced by https://github.com/XenonMolecule/github-action-push-to-another-repository/blob/main/entrypoint.sh

set -e  # stop exec on command fail
set -u  # stop when accessing an undefined variable
set -o xtrace

COPY_DIR="public"
DEST_BRANCH="master"
GITHUB_USER_NAME="paulbarbu"
TARGET_REPO="paulbarbu.github.io"
CLONE_DIR=$(mktemp -d)

echo "Cloning destination git repository"

git config --global user.name "github-actions[bot]"
git config --global user.email "41898282+github-actions[bot]@users.noreply.github.com"
git clone --single-branch --branch "$DEST_BRANCH" "https://$GITHUB_USER_NAME:$TARGET_REPO_TOKEN@github.com/$GITHUB_USER_NAME/$TARGET_REPO.git" "$CLONE_DIR"
ls -la "$CLONE_DIR"

TEMP_DIR=$(mktemp -d)
# This mv has been the easier way to be able to remove files that were there
# but not anymore. Otherwise we had to remove the files from "$CLONE_DIR",
# including "." and with the exception of ".git/"
mv "$CLONE_DIR/.git" "$TEMP_DIR/.git"

# Remove contents of target directory and create a new empty one
rm -Rf "$CLONE_DIR/$COPY_DIR/"
mkdir "$CLONE_DIR/$COPY_DIR"

mv "$TEMP_DIR/.git" "$CLONE_DIR/.git"

echo "Copy contents to target git repository"
cp -ra "$COPY_DIR"/. "$CLONE_DIR/$COPY_DIR"
cd "$CLONE_DIR"

echo "Files that will be pushed:"
ls -la

echo "git add:"
git add .

echo "git status:"
git status

echo "git diff-index:"
# git diff-index: to avoid failing the git commit if there are no changes to be committed
git diff-index --quiet HEAD || git commit --message "Update site on $(date)"

echo "git push origin:"
# --set-upstream: sets de branch when pushing to a branch that does not exist
git push "https://$GITHUB_USER_NAME:$TARGET_REPO_TOKEN@github.com/$GITHUB_USER_NAME/$TARGET_REPO.git" --set-upstream "$DEST_BRANCH"
