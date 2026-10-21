#!/bin/sh
set -eu

base_image="${BASE_IMAGE:-wodby/drupal-php@sha256:a97a10f209006fdd5ead19b4ccb47ae6a53044ba48942c1597b505eb84d5c55a}"
fixed_image="${FIXED_IMAGE:-drupal-php-backport:test}"
artifact_dir="${ARTIFACT_DIR:-.artifacts}"

mkdir -p "$artifact_dir"

docker run --rm --entrypoint php "$base_image" -m | sort > "$artifact_dir/base-modules.txt"
docker run --rm --entrypoint php "$fixed_image" -m | sort > "$artifact_dir/fixed-modules.txt"
diff -u "$artifact_dir/base-modules.txt" "$artifact_dir/fixed-modules.txt"

docker run --rm --entrypoint php "$fixed_image" -r '
if (PHP_VERSION !== "7.4.34-dev") {
    fwrite(STDERR, "Unexpected PHP version: " . PHP_VERSION . PHP_EOL);
    exit(1);
}
echo "PHP runtime smoke test passed", PHP_EOL;
'

docker run --rm --user root --entrypoint php-fpm "$fixed_image" --test

base_entrypoint="$(docker image inspect "$base_image" --format '{{json .Config.Entrypoint}}')"
fixed_entrypoint="$(docker image inspect "$fixed_image" --format '{{json .Config.Entrypoint}}')"
test "$base_entrypoint" = "$fixed_entrypoint"

base_cmd="$(docker image inspect "$base_image" --format '{{json .Config.Cmd}}')"
fixed_cmd="$(docker image inspect "$fixed_image" --format '{{json .Config.Cmd}}')"
test "$base_cmd" = "$fixed_cmd"

base_user="$(docker image inspect "$base_image" --format '{{.Config.User}}')"
fixed_user="$(docker image inspect "$fixed_image" --format '{{.Config.User}}')"
test "$base_user" = "$fixed_user"

container_id="$(docker run -d "$fixed_image")"
cleanup() {
    docker logs "$container_id" || true
    docker rm -f "$container_id" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

attempt=0
while [ "$attempt" -lt 30 ]; do
    if docker exec "$container_id" sh -c 'test -r /proc/1/status'; then
        echo "Container entrypoint smoke test passed."
        exit 0
    fi
    attempt=$((attempt + 1))
    sleep 1
done

echo "Container did not become healthy enough for the entrypoint smoke check." >&2
exit 1
