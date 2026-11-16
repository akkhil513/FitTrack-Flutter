#!/usr/bin/env bash
#
# FitTrack Flutter web: analyze, test, build and publish to the S3 website bucket.
#
#   ./deploy.sh                 build and publish (asks before uploading)
#   ./deploy.sh --dry-run       build and show what would change in S3; upload nothing
#   ./deploy.sh --yes           do not ask for confirmation
#   ./deploy.sh --skip-tests    skip flutter analyze/test (not recommended)
#   ./deploy.sh --no-delete     do not remove files from the bucket that are not in this build
#
# Needs: Flutter SDK, AWS CLI configured for the account that owns the bucket, curl.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

BUCKET="${BUCKET:-fittrack-flutter-app}"
BACKEND_STACK="${BACKEND_STACK:-fittrack-stack}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
SITE_URL="http://${BUCKET}.s3-website-${AWS_DEFAULT_REGION}.amazonaws.com"

DRY_RUN=false; ASSUME_YES=false; SKIP_TESTS=false; DELETE=true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)    DRY_RUN=true ;;
    --yes|-y)     ASSUME_YES=true ;;
    --skip-tests) SKIP_TESTS=true ;;
    --no-delete)  DELETE=false ;;
    -h|--help)    sed -n '2,11p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1 (try --help)" >&2; exit 2 ;;
  esac
  shift
done

say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[33mWARN: %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }
confirm() { $ASSUME_YES && return 0; read -r -p "$1 [y/N] " r; [[ "$r" == "y" || "$r" == "Y" ]]; }

# ---- 1. preflight ------------------------------------------------------------
say "Preflight"
command -v flutter >/dev/null || die "Flutter not found on PATH"
command -v aws     >/dev/null || die "AWS CLI not found"
command -v curl    >/dev/null || die "curl not found"
[[ -f pubspec.yaml ]] || die "run from the Flutter project root"

echo "AWS identity : $(aws sts get-caller-identity --query '[Account,Arn]' --output text)" \
  || die "AWS credentials are not working"
aws s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1 || die "S3 bucket '$BUCKET' not reachable"
echo "Bucket       : $BUCKET"
echo "Site         : $SITE_URL"
$DRY_RUN && echo "Mode         : DRY RUN (nothing will be uploaded)"

# The built app must point at the live API.
APP_API="$(grep -o "https://[a-z0-9]*\.execute-api\.[a-z0-9-]*\.amazonaws\.com" lib/services/api_service.dart | head -1 || true)"
LIVE_API="$(aws cloudformation describe-stacks --stack-name "$BACKEND_STACK" \
  --query "Stacks[0].Outputs[?OutputKey=='ApiEndpoint'].OutputValue" --output text 2>/dev/null || true)"
LIVE_API="${LIVE_API%/}"
if [[ -z "$LIVE_API" || "$LIVE_API" == "None" ]]; then
  warn "Could not read the backend ApiEndpoint from stack '$BACKEND_STACK'; skipping the API URL check."
elif [[ "$APP_API" != "$LIVE_API" ]]; then
  die "api_service.dart points at '$APP_API' but the live API is '$LIVE_API'. Fix baseUrl first."
else
  echo "API URL      : $APP_API (matches backend stack)"
fi

# ---- 2. checks ---------------------------------------------------------------
flutter pub get >/dev/null
if $SKIP_TESTS; then
  warn "Skipping analyze and tests"
else
  say "flutter analyze"
  flutter analyze
  say "flutter test"
  flutter test
fi

# ---- 3. build ----------------------------------------------------------------
say "Building web release"
flutter build web --release
[[ -s build/web/index.html && -s build/web/main.dart.js ]] || die "build/web is incomplete"
du -sh build/web | sed 's/^/Build size   : /'

# Files that must never be served stale; everything else (assets, canvaskit, icons) is cached long.
ENTRY_FILES=(index.html flutter_bootstrap.js flutter_service_worker.js version.json manifest.json main.dart.js flutter.js favicon.png .last_build_id)
EXCLUDES=(); for f in "${ENTRY_FILES[@]}"; do EXCLUDES+=(--exclude "$f"); done
DELETE_FLAG=(); $DELETE && DELETE_FLAG=(--delete)

# ---- 4. preview + upload -----------------------------------------------------
say "Preview of changes to s3://$BUCKET"
aws s3 sync build/web "s3://$BUCKET" "${EXCLUDES[@]}" "${DELETE_FLAG[@]}" --dryrun
echo "Entry files (always revalidated): ${ENTRY_FILES[*]}"

if $DRY_RUN; then say "Dry run complete: nothing was uploaded"; exit 0; fi
confirm "Publish this build to s3://$BUCKET?" || die "Aborted"

say "Uploading assets"
aws s3 sync build/web "s3://$BUCKET" "${EXCLUDES[@]}" "${DELETE_FLAG[@]}" \
  --cache-control "public,max-age=31536000" --only-show-errors

# Entry files go last so index.html never points at files that are not there yet.
say "Uploading entry files"
for f in "${ENTRY_FILES[@]}"; do
  [[ -f "build/web/$f" ]] && aws s3 cp "build/web/$f" "s3://$BUCKET/$f" \
    --cache-control "no-cache" --only-show-errors
done

# ---- 5. smoke tests ----------------------------------------------------------
say "Smoke tests"
FAILED=0
check() {  # check <description> <expected status> <url>
  local code; code="$(curl -s -o /dev/null -m 20 -w '%{http_code}' "$3" || true)"
  if [[ "$code" == "$2" ]]; then printf '  PASS  %s (%s)\n' "$1" "$code"
  else printf '  FAIL  %s (expected %s, got %s)\n' "$1" "$2" "${code:-000}"; FAILED=1; fi
}
check "index.html"                200 "$SITE_URL/"
check "main.dart.js"              200 "$SITE_URL/main.dart.js"
# S3 website hosting serves the error document (index.html) with a 404 status, so check the body, not the code.
if curl -s -m 20 "$SITE_URL/plan" | grep -q "flutter_bootstrap.js"; then
  printf '  PASS  %s\n' "deep link serves the app shell"
else
  printf '  FAIL  %s\n' "deep link does not serve the app shell"; FAILED=1
fi
[[ $FAILED -eq 0 ]] || die "Smoke tests failed"

say "Deployed OK"
echo "Open: $SITE_URL"
echo "If you still see the old version, hard-refresh once (Cmd+Shift+R): the old service worker updates on the next load."
