#!/usr/bin/env python3
"""Gate publication on the parallel, real-tap production-control UI tests."""
import json
import os
import subprocess
import time

repo = os.environ['GITHUB_REPOSITORY']
run = os.environ['GITHUB_RUN_ID']
deadline = time.monotonic() + 36 * 60
next_notice = 0
while time.monotonic() < deadline:
    try:
        payload = json.loads(subprocess.check_output(
            ['gh', 'api', f'repos/{repo}/actions/runs/{run}/jobs?per_page=100'], timeout=30,
        ))
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        print(f'Retrying the simulator status check after {type(error).__name__}.', flush=True)
        time.sleep(10)
        continue
    job = next((job for job in payload['jobs'] if job['name'] == 'Verify lyrics interactions on iPad'), None)
    if job and job['status'] == 'completed':
        if job['conclusion'] != 'success':
            raise SystemExit(f"Production lyrics interaction tests failed: {job['html_url']}")
        print('Production lyrics interaction tests passed; publication permitted.')
        break
    now = time.monotonic()
    if now >= next_notice:
        print('Waiting for parallel iPad production-control interaction tests...', flush=True)
        next_notice = now + 60
    time.sleep(10)
else:
    raise SystemExit('Timed out waiting for lyrics interaction tests; release blocked.')
