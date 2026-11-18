#!/usr/bin/env bash
# Decides which upstream branches and tags need a (new) image and prints them
# as a JSON array for the build matrix.
#
# A branch is rebuilt when its head commit or the build recipe changed since
# the image was pushed. A tag is built once; its sources and the base images
# they pin never change. FORCE=true rebuilds everything selected.
#
# Environment:
#   UPSTREAM        owner/repo of the sources, e.g. prusa3d/prusa-connect
#   IMAGE           image to compare against, e.g. ghcr.io/rockordier/prusa-connect-unofficial
#   RECIPE          hash of the files that shape the image (workflow, scripts)
#   ONLY_REF        build only this branch or tag (optional)
#   FORCE           true rebuilds even when nothing changed (optional)
#   BRANCH_INCLUDE  extended regex of branches to build (default: all)
#   BRANCH_EXCLUDE  extended regex of branches to skip
set -euo pipefail

: "${UPSTREAM:?}" "${IMAGE:?}" "${RECIPE:?}"
ONLY_REF="${ONLY_REF:-}"
FORCE="${FORCE:-false}"
BRANCH_INCLUDE="${BRANCH_INCLUDE:-.*}"
BRANCH_EXCLUDE="${BRANCH_EXCLUDE:-^cla-signatures$}"

refs=$(git ls-remote --heads --tags "https://github.com/${UPSTREAM}.git")

# Highest stable release (vX.Y.Z without a pre-release part) gets `latest`.
latest=$(awk '{print $2}' <<<"$refs" \
    | sed -n 's|^refs/tags/v\([0-9]*\.[0-9]*\.[0-9]*\)$|\1|p' \
    | sort -V | tail -n1)

# Docker tags allow [A-Za-z0-9_.-], at most 128 characters, no leading . or -.
docker_tag() {
    tr '[:upper:]' '[:lower:]' <<<"$1" | sed -e 's|[^a-z0-9_.-]|-|g' -e 's|^[.-]*||' | cut -c1-100
}

# Prints "<revision> <recipe>" of a pushed image, or nothing when it is missing.
pushed_labels() {
    skopeo inspect --override-os linux --override-arch amd64 "docker://${IMAGE}:$1" 2>/dev/null \
        | jq -r '[.Labels["org.opencontainers.image.revision"] // "", .Labels["prusa-connect-unofficial.recipe"] // ""] | join(" ")' \
        || true
}

targets='[]'
add_target() { # kind name sha tag version
    local kind=$1 name=$2 sha=$3 tag=$4 version=$5 extra_tags=""
    if [ "$kind" = tag ] && [ "$version" = "$latest" ]; then
        extra_tags="latest"
    fi
    targets=$(jq -c --arg kind "$kind" --arg name "$name" --arg sha "$sha" --arg tag "$tag" \
        --arg version "$version" --arg extra "$extra_tags" --arg key "$(docker_tag "$kind-$name")" \
        '. + [{kind: $kind, name: $name, sha: $sha, tag: $tag, version: $version, extra_tags: $extra, key: $key}]' \
        <<<"$targets")
}

while read -r sha ref; do
    case "$ref" in
        refs/heads/*)
            kind=branch; name=${ref#refs/heads/}
            [[ "$name" =~ $BRANCH_INCLUDE ]] || continue
            [[ "$name" =~ $BRANCH_EXCLUDE ]] && continue
            tag=$(docker_tag "$name")
            [ "$tag" = latest ] && continue
            version=""
            ;;
        refs/tags/v[0-9]*)
            [[ "$ref" == *'^{}' ]] && continue
            kind=tag; name=${ref#refs/tags/}
            # An annotated tag points at a tag object; the commit is the peeled ref.
            peeled=$(awk -v r="$ref^{}" '$2 == r {print $1}' <<<"$refs")
            sha=${peeled:-$sha}
            version=${name#v}
            tag=$(docker_tag "$version")
            ;;
        *) continue ;;
    esac

    if [ -n "$ONLY_REF" ] && [ "$ONLY_REF" != "$name" ]; then
        continue
    fi

    read -r pushed_sha pushed_recipe <<<"$(pushed_labels "$tag")" || true
    reason=""
    if [ "$FORCE" = true ]; then
        reason="forced"
    elif [ -z "${pushed_sha:-}" ]; then
        reason="no image yet"
    elif [ "$kind" = branch ] && [ "$pushed_sha" != "$sha" ]; then
        reason="new commit ${pushed_sha:0:12} -> ${sha:0:12}"
    elif [ "$kind" = branch ] && [ "${pushed_recipe:-}" != "$RECIPE" ]; then
        reason="recipe changed"
    fi

    if [ -n "$reason" ]; then
        echo "build  $kind $name ($reason)" >&2
        add_target "$kind" "$name" "$sha" "$tag" "$version"
    else
        echo "skip   $kind $name (up to date at ${sha:0:12})" >&2
    fi
done <<<"$refs"

if [ -n "$ONLY_REF" ] && [ "$targets" = '[]' ] && [ "$FORCE" = true ]; then
    echo "::error::$ONLY_REF is neither a branch nor a v* tag of $UPSTREAM" >&2
    exit 1
fi

echo "$targets"
