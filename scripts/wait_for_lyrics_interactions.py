#!/usr/bin/env python3
"""Gate publication on the parallel, real-tap production-control UI tests."""
import json
import os
import subprocess
import time

repo = os.environ['GITHUB_REPOSITORY']
run = os.environ['GITHUB_RUN_ID']
for attempt in range(216):
    payload = json.loads(subprocess.check_output(['gh', 'api', f'repos/{repo}/actions/runs/{run}/jobs?per_page=100']))
    job = next((job for job in payload['jobs'] if job['name'] == 'Verify lyrics interactions on iPad'), None)
    if job and job['status'] == 'completed':
        if job['conclusion'] != 'success':
            raise SystemExit(f"Production lyrics interaction tests failed: {job['html_url']}")
        print('Production lyrics interaction tests passed; publication permitted.')
        break
    if attempt % 6 == 0: print('Waiting for parallel iPad production-control interaction tests...', flush=True)
    time.sleep(10)
else:
    raise SystemExit('Timed out waiting for lyrics interaction tests; release blocked.')
