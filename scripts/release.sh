#!/usr/bin/env bash

##
# Release tasks bulked into one script w/ user
# intervention/confirmation required.
#
# - Bumps 'package.json' version field to the passed <semver> arg (1).
# - Commit and push the change (to master).
# - Create and push passed <semver> arg (1) git tag.
# - Run npm publish.
#
# Usage:
#
# From the 'master' branch... run:
#
#     release.sh <semver>
#
# Example:
#
#     bash release.sh 1.2.1
##

set -e

VERSION=$1

readonly SCRIPTSDIR="$(cd "$(dirname "${0}")"; echo "$(pwd)")"
readonly SCRIPTNAME="$(basename "${BASH_SOURCE[0]}")"


show_info() {
    local msg="$1"
    echo -e "\e[36m${1}\e[0m"
}

show_success() {
    local msg="$1"
    echo -e "\e[32m${msg}\e[0m"
}

show_warning() {
    local msg="$1"
    echo -e "\e[33mwarning\e[0m : ${1}"
}

show_error() {
    local msg="$1"
    echo -e "\e[31merror\e[0m : ${1}"
}


cd_project_root() {
    show_info '> cd to project root'
    pushd "${SCRIPTSDIR}" && pushd ..
}

restore_previous_working_dir() {
    show_info '> Restore previous working directory'
    popd && popd
}

ensure_semver_arg() {
    if [[ ! ${VERSION} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        show_error "$VERSION is not a valid semver (ex: 1.2.1)"
        exit 1
    fi
}

ensure_git_branch_is_master() {
    show_info "> Ensure current branch is 'master'"
    local git_branch=$(git rev-parse --abbrev-ref HEAD)
    if [ "$git_branch" != "master" ]; then
        show_error "$SCRIPTNAME must be run from the 'master' branch (current branch is: '$git_branch')."
        exit 1
    fi
}

ensure_git_repo_is_clean() {
    show_info "> Ensure repo is clean"
    if ! git diff-index --quiet HEAD --; then
        show_error "git repo is dirty. Commit all changes before using $SCRIPTNAME."
        exit 1
    fi
}

bump_package_json_version() {
    show_info "> Bump version in 'package.json' file"
    TMPPKGFILE="${TMPDIR:-/tmp}/package.json.$$"
    sed -E s/'"version"\: "[0-9]+\.[0-9]+\.[0-9]+"'/'"version"\: "'"$VERSION"'"'/ package.json > "$TMPPKGFILE" && mv "$TMPPKGFILE" package.json
    grep "$VERSION" -C 1 package.json
}

ensure_only_one_file_changed() {
    show_info "> Ensure only one file changed (package.json and version field)"
    if [[ ! $(git diff --stat) =~ "1 file changed, 1 insertion(+), 1 deletion(-)" ]]; then
        show_error "WARNING! Expected exactly 1 change in 1 file after replacing version number. Bailing! (check git status and git diff)"
        exit 1
    fi
}

confirm_git_commit_tag_release() {
    show_success "> Acquire confirmations"
    while true; do
        read -r -p "Ready to build, commit, tag and release v$VERSION? (y/n): " yn
        case ${yn} in
            [Yy]* )   break;;
            [NnQq]* ) exit;;
            * ) show_warning "Please answer w [Y]es or [N]o.";;
        esac
    done
}

git_commit_tag_release() {
    show_info "> git commit/push/tag/push --tags"
    set -x
    git add package.json
    git commit -m "Bump to v$VERSION"
    git push origin master
    git tag -a "$VERSION" -m "Tag v$VERSION"
    git push --tags
    set +x
}

run_npm_publish() {
    echo
    show_info "> Publish npm package"
    npm publish
}


main() {
    cd_project_root
    ensure_semver_arg
    ensure_git_branch_is_master
    ensure_git_repo_is_clean
    bump_package_json_version
    ensure_only_one_file_changed
    confirm_git_commit_tag_release
    git_commit_tag_release
    run_npm_publish
    restore_previous_working_dir
    echo && show_success "Finished." && echo
}

main
