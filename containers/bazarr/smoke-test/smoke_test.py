"""Smoke test of the final image, run by the Containerfile's last RUN.

The image has no shell, so this runs as the image's user, in the final
stage, with the interpreter the image ships. It checks what a release can
break:

- FFmpeg and unrar run: the libraries copied from Debian are found.
- FFmpeg decodes through the filters Bazarr's Whisper provider uses
  (custom_libs/subliminal_patch/providers/whisperai.py), and ffprobe reads
  the result.
- Every compiled module imports. Bazarr itself doesn't check them: with
  NO_UPDATE its start-up imports skip (bazarr/init.py).
- Bazarr starts as the image runs it (the ENTRYPOINT and the ENV),
  answers on its health endpoint, reports BASE_VERSION (a build argument,
  so in the environment of the RUN), and stops in order on SIGINT.
"""

import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import urllib.request

INSTALL = "/usr/lib/bazarr"
BASE_URL = "http://127.0.0.1:6767"
# main.py's exit status after SIGINT: os._exit(EXIT_INTERRUPT), -100,
# seen by the parent as 156 (bazarr/literals.py).
EXIT_INTERRUPT = 156
STARTUP_TIMEOUT = 180
STOP_TIMEOUT = 30


def run(*command: str) -> str:
    result = subprocess.run(command, check=True, capture_output=True, text=True)
    return result.stdout


def check_binaries(work: str) -> None:
    run("unrar")
    pcm = os.path.join(work, "sine.pcm")
    mkv = os.path.join(work, "sine.mkv")
    # The Whisper provider's chain: trim, delay, resample, to 16 kHz mono
    # s16le (custom_libs/subliminal_patch/providers/whisperai.py).
    run(
        "ffmpeg", "-nostdin", "-v", "error",
        "-f", "lavfi", "-i", "sine=frequency=440:duration=2",
        "-af", "atrim=start=0.1,asetpts=PTS-STARTPTS,adelay=100|100,aresample=async=1",
        "-ac", "1", "-ar", "16000", "-f", "s16le", pcm,
    )
    # 2 s at 16 kHz, 2 bytes a sample, minus the 0.1 s trimmed and plus the
    # 0.1 s delay: about 64000 bytes.
    size = os.path.getsize(pcm)
    assert 60000 < size < 68000, f"decoded audio is {size} bytes"
    run(
        "ffmpeg", "-nostdin", "-v", "error",
        "-f", "lavfi", "-i", "sine=frequency=440:duration=1",
        "-c:a", "pcm_s16le", mkv,
    )
    streams = json.loads(run("ffprobe", "-v", "error", "-show_streams", "-of", "json", mkv))
    codecs = [stream["codec_name"] for stream in streams["streams"]]
    assert codecs == ["pcm_s16le"], f"ffprobe read {codecs}"


def check_modules() -> None:
    # libs/ is on Bazarr's sys.path (bazarr/app/libs.py), and holds them.
    code = (
        f"import sys; sys.path.insert(0, '{INSTALL}/libs'); "
        "import lxml.etree, numpy, PIL.Image, psycopg2, sqlite3, webrtcvad, setuptools"
    )
    run(sys.executable, "-c", code)


def get(path: str, api_key: str | None = None) -> bytes:
    request = urllib.request.Request(BASE_URL + path)
    if api_key:
        request.add_header("X-API-KEY", api_key)
    with urllib.request.urlopen(request, timeout=10) as response:
        return response.read()


def check_server(work: str) -> None:
    config = os.path.join(work, "config")
    log = open(os.path.join(work, "bazarr.log"), "w+")
    # What the Containerfile's ENTRYPOINT runs, with a throwaway --config.
    server = subprocess.Popen(
        [sys.executable, os.path.join(INSTALL, "bazarr", "main.py"), "--config", config],
        stdout=log,
        stderr=subprocess.STDOUT,
    )
    try:
        deadline = time.monotonic() + STARTUP_TIMEOUT
        while True:
            assert server.poll() is None, f"Bazarr exited with status {server.returncode}"
            try:
                get("/api/system/ping")
                break
            except OSError:
                assert time.monotonic() < deadline, "Bazarr didn't answer in time"
                time.sleep(1)
        with open(os.path.join(config, "config", "config.yaml")) as file:
            match = re.search(r"^\s*apikey:\s*(\S+)", file.read(), re.MULTILINE)
        assert match, "no API key in config.yaml"
        status = json.loads(get("/api/system/status", match.group(1)))["data"]
        assert status["bazarr_version"] == os.environ["BASE_VERSION"], status
        server.send_signal(signal.SIGINT)
        assert server.wait(STOP_TIMEOUT) == EXIT_INTERRUPT, "Bazarr didn't stop in order"
    except BaseException:
        server.kill()
        log.seek(0)
        sys.stderr.write(log.read())
        raise
    finally:
        log.close()


def main() -> None:
    # /tmp: the image's volume, writable by its user.
    work = tempfile.mkdtemp(prefix="smoke-")
    try:
        check_binaries(work)
        check_modules()
        check_server(work)
    finally:
        shutil.rmtree(work, ignore_errors=True)
        # The stop file main.py writes (STOPFILE).
        for path in (os.environ["STOPFILE"], os.environ["RESTARTFILE"]):
            if os.path.exists(path):
                os.remove(path)


if __name__ == "__main__":
    main()
