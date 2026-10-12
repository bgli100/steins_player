r"""Turn the CI build into the release .ipa.

The iOS job has no res\ (the videos are not in the repository), so it builds with
stubs from tool/stub_assets.sh: 1.9 KB videos and an AssetManifest.bin that lists
only the nine stub paths. Both have to be replaced for a package that can play
the real works:

  * res\ comes from this checkout;
  * AssetManifest.bin comes from a package that was built with the real files -
    the Windows or Android one, produced by the same Flutter tool. Image.asset()
    reads that manifest, so without the swap the covers would throw while the
    videos (loaded by path) would work.

Usage:
    # with an .ipa downloaded from the workflow run
    python tool/build_ios_ipa.py --ipa path/to/LullabyCore-unsigned.ipa

    # or let it fetch the newest artifact of the ios workflow
    set GITHUB_TOKEN=...   (or GH_TOKEN; it falls back to the git credential store)
    python tool/build_ios_ipa.py --from-ci latest

    # an older run, or a manifest from a specific package
    python tool/build_ios_ipa.py --from-ci 123456789 --manifest-from dist/old.zip

The result is written as dist/Lullaby Core <version>-ios.ipa, the same naming the
other platforms use. It stays unsigned: a sideloading tool or Xcode has to sign it
before a device accepts it.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSET_PREFIX = "Payload/Runner.app/Frameworks/App.framework/flutter_assets"
MANIFEST_NAME = "AssetManifest.bin"
ARTIFACT_NAME = "lullaby-core-unsigned-ipa"


def log(message):
    print(message, flush=True)


def app_version():
    with open(os.path.join(REPO_ROOT, "pubspec.yaml"), encoding="utf-8") as f:
        match = re.search(r"(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)", f.read())
    if not match:
        raise SystemExit("no version in pubspec.yaml")
    return match.group(1)


def find_manifest(source):
    """The AssetManifest.bin of a package built with the real assets.

    [source] is a .zip/.apk/.hap/.ipa, or the .bin itself.
    """
    if source.endswith(MANIFEST_NAME):
        with open(source, "rb") as f:
            return f.read(), source
    with zipfile.ZipFile(source) as z:
        names = [n for n in z.namelist() if n.endswith(MANIFEST_NAME)]
        if not names:
            raise SystemExit(f"{source}: no {MANIFEST_NAME} inside")
        for name in names:
            data = z.read(name)
            # A stub build lists only res/global and the covers; a real one lists
            # the work segments too.
            if b"res/works/" in data and b"segments/" in data:
                return data, f"{source} [{name}]"
    raise SystemExit(
        f"{source}: its manifest has no work assets - build that package with a "
        f"real res\\ (tool/stub_assets.sh skips a checkout that has them)"
    )


def default_manifest_source():
    """The newest package in dist\\ that was built with the real assets."""
    dist = os.path.join(REPO_ROOT, "dist")
    if not os.path.isdir(dist):
        return None
    candidates = [os.path.join(dist, n) for n in os.listdir(dist)
                  if n.endswith(("-windows.zip", "-android.apk", "-ohos.hap"))]
    for path in sorted(candidates, key=os.path.getmtime, reverse=True):
        try:
            find_manifest(path)
            return path
        except SystemExit:
            continue
    return None


def git_remote_repo():
    url = subprocess.run(["git", "remote", "get-url", "origin"], cwd=REPO_ROOT,
                         capture_output=True, text=True).stdout.strip()
    match = re.search(r"github\.com[:/]([^/]+/[^/.]+)", url)
    if not match:
        raise SystemExit(f"cannot read owner/repo from {url!r}")
    return match.group(1)


def github_token():
    for name in ("GITHUB_TOKEN", "GH_TOKEN"):
        if os.environ.get(name):
            return os.environ[name]
    # The credential the repository is pushed with.
    result = subprocess.run(["git", "credential", "fill"], cwd=REPO_ROOT,
                            input="protocol=https\nhost=github.com\n\n",
                            capture_output=True, text=True)
    for line in result.stdout.splitlines():
        if line.startswith("password="):
            return line[len("password="):]
    raise SystemExit("no GitHub token: set GITHUB_TOKEN, or pass --ipa")


class _NoCrossHostAuth(urllib.request.HTTPRedirectHandler):
    """Drops the Authorization header when a redirect leaves the API host.

    The artifact download answers with a redirect to a signed URL, and a token
    sent along to it is rejected with 401. curl strips the header on a
    cross-host redirect, urllib does not.
    """

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        new = super().redirect_request(req, fp, code, msg, headers, newurl)
        if new is None:
            return None
        if urllib.parse.urlsplit(newurl).netloc != urllib.parse.urlsplit(req.full_url).netloc:
            for name in list(new.headers):
                if name.lower() == "authorization":
                    del new.headers[name]
        return new


_opener = urllib.request.build_opener(_NoCrossHostAuth)


def api(url, token, attempts=5):
    """GET with a token; this machine's proxy fails TLS handshakes now and then."""
    request = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
    })
    delay = 2
    for attempt in range(1, attempts + 1):
        try:
            with _opener.open(request) as response:
                return response.read()
        except (urllib.error.URLError, ConnectionError, TimeoutError) as error:
            if attempt == attempts:
                raise SystemExit(f"{url} failed after {attempts} attempts: {error}")
            log(f"retrying ({attempt}/{attempts}): {error}")
            time.sleep(delay)
            delay *= 2


def fetch_from_ci(run, token, repo, workdir):
    """Downloads the unsigned ipa artifact of a workflow run."""
    if run == "latest":
        data = json.loads(api(
            f"https://api.github.com/repos/{repo}/actions/workflows/ios.yml/runs"
            f"?branch=main&status=success&per_page=1", token))
        runs = data.get("workflow_runs") or []
        if not runs:
            raise SystemExit("no successful ios run found")
        run_id = runs[0]["id"]
    else:
        run_id = str(run)
    data = json.loads(api(
        f"https://api.github.com/repos/{repo}/actions/runs/{run_id}/artifacts", token))
    artifacts = [a for a in data.get("artifacts", []) if a["name"] == ARTIFACT_NAME]
    if not artifacts:
        raise SystemExit(f"run {run_id} has no {ARTIFACT_NAME} artifact")
    log(f"downloading {ARTIFACT_NAME} of run {run_id} "
        f"({artifacts[0]['size_in_bytes'] / 1e6:.1f} MB)")
    blob = api(artifacts[0]["archive_download_url"], token)
    archive = os.path.join(workdir, "artifact.zip")
    with open(archive, "wb") as f:
        f.write(blob)
    with zipfile.ZipFile(archive) as z:
        name = next(n for n in z.namelist() if n.endswith(".ipa"))
        target = os.path.join(workdir, "ci.ipa")
        with z.open(name) as src, open(target, "wb") as dst:
            shutil.copyfileobj(src, dst)
    return target


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--ipa", help="the unsigned .ipa to package")
    source.add_argument("--from-ci", metavar="RUN",
                        help="download the artifact of an ios run ('latest' for the newest)")
    parser.add_argument("--manifest-from",
                        help="package built with the real assets (default: newest in dist\\)")
    parser.add_argument("--assets", default=os.path.join(REPO_ROOT, "res"),
                        help="the real res\\ to put in (default: this checkout)")
    parser.add_argument("--out", help="output path (default: dist\\Lullaby Core <version>-ios.ipa)")
    parser.add_argument("--keep-temp", action="store_true")
    args = parser.parse_args()

    loading = os.path.join(args.assets, "global", "loading.mp4")
    if not os.path.exists(loading) or os.path.getsize(loading) < 1_000_000:
        raise SystemExit(f"{args.assets} does not hold the real assets "
                         f"(res\\global\\loading.mp4 is missing or a stub)")

    manifest_source = args.manifest_from or default_manifest_source()
    if not manifest_source:
        raise SystemExit("no package in dist\\ carries a real-asset manifest; "
                         "pass --manifest-from")
    manifest, manifest_origin = find_manifest(manifest_source)
    log(f"manifest: {len(manifest)} bytes from {manifest_origin}")

    workdir = tempfile.mkdtemp(prefix="ios-ipa-")
    try:
        ipa = args.ipa
        if args.from_ci:
            token = github_token()
            ipa = fetch_from_ci(args.from_ci, token, git_remote_repo(), workdir)
        log(f"source ipa: {ipa} ({os.path.getsize(ipa) / 1e6:.1f} MB)")

        stage = os.path.join(workdir, "stage")
        with zipfile.ZipFile(ipa) as z:
            z.extractall(stage)
        assets_dir = os.path.join(stage, *ASSET_PREFIX.split("/"))
        if not os.path.isdir(assets_dir):
            raise SystemExit(f"{ipa} does not have {ASSET_PREFIX}")

        start = time.time()
        shutil.rmtree(os.path.join(assets_dir, "res"))
        shutil.copytree(args.assets, os.path.join(assets_dir, "res"))
        with open(os.path.join(assets_dir, MANIFEST_NAME), "wb") as f:
            f.write(manifest)
        count = sum(len(files) for _, _, files in os.walk(os.path.join(assets_dir, "res")))
        size = sum(os.path.getsize(os.path.join(r, f))
                   for r, _, fs in os.walk(os.path.join(assets_dir, "res")) for f in fs)
        log(f"assets: {count} files, {size / 1e9:.2f} GB ({time.time() - start:.0f}s)")

        out = args.out or os.path.join(
            REPO_ROOT, "dist", f"Lullaby Core {app_version()}-ios.ipa")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        start = time.time()
        with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=1) as z:
            for root, _, files in os.walk(stage):
                for name in files:
                    path = os.path.join(root, name)
                    z.write(path, os.path.relpath(path, stage))
        log(f"written: {out} ({os.path.getsize(out) / 1e9:.2f} GB, "
            f"packed in {time.time() - start:.0f}s)")

        with zipfile.ZipFile(out) as z:
            members = z.namelist()
            res = [n for n in members if f"{ASSET_PREFIX}/res/" in n]
            manifest_in_ipa = z.read(f"{ASSET_PREFIX}/{MANIFEST_NAME}")
            broken = z.testzip()
        log(f"verify: {len(members)} entries, {len(res)} assets, "
            f"manifest {len(manifest_in_ipa)} bytes, "
            f"{'ok' if broken is None else 'CORRUPT: ' + broken}")
        log("note: unsigned - a sideloading tool has to sign it for a device")
    finally:
        if args.keep_temp:
            log(f"temp kept at {workdir}")
        else:
            shutil.rmtree(workdir, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
