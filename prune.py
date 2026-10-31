#!/usr/bin/env python3
"""Прореживание архивов mongodump в S3 (Backblaze B2) по всем серверам сразу.

Политика (возраст считается по времени в имени файла, mongodump_YYYY-MM-DDTHH-MMZ.archive.gz):
  * моложе 12 ч           — храним все;
  * от 12 до 48 ч         — в каждом 6-часовом окне (00/06/12/18 UTC) оставляем самый свежий архив;
  * старше 48 ч           — в каждом 12-часовом окне (00/12 UTC) оставляем самый свежий архив.
Верхнюю границу хранения задаёт lifecycle-правило бакета (скрытие через 3 дня).

Окна общие для всех серверов (mongodump/<сервер>/...), т.к. сервера бэкапят по очереди.
Защита: самый свежий архив каждого сервера не удаляется никогда; файлы с другими именами
(status.json и т.п.) не трогаются; при ошибке листинга или пустом списке ничего не удаляется.

Переменные окружения: S3CFG, BUCKET_NAME, PRUNE_PREFIX (mongodump/), PRUNE_DRY_RUN=1 — только показать,
PRUNE_MAX_AGE_DAYS — удалять архивы старше N дней (для префиксов без lifecycle-правила, например mongodump-stage/),
PRUNE_KEEP_LAST — хранить только N последних архивов каждого сервера (вместо окон; например 3 для стейджа).
В B2 удаление через S3 API скрывает файл; окончательно его удаляет lifecycle через сутки после скрытия.
"""
import os
import re
import subprocess
import sys
from datetime import datetime, timezone

HOUR = 3600
KEEP_ALL_SEC = 12 * HOUR
TIER1_UNTIL_SEC = 48 * HOUR
TIER1_WINDOW = 6 * HOUR
TIER2_WINDOW = 12 * HOUR

NAME_RE = re.compile(r'^(?P<server>[^/]+)/mongodump_(?P<d>\d{4}-\d{2}-\d{2})T(?P<h>\d{2})-(?P<m>\d{2})Z\.archive\.gz$')


def log(msg):
    print(f"[prune {datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}] {msg}", flush=True)


def plan(keys, now):
    """keys: список путей относительно префикса (<сервер>/mongodump_...). Возвращает (keep, delete)."""
    items = []
    for k in keys:
        m = NAME_RE.match(k)
        if not m:
            continue
        ts = int(datetime.strptime(f"{m['d']}T{m['h']}:{m['m']}", '%Y-%m-%dT%H:%M').replace(tzinfo=timezone.utc).timestamp())
        items.append({'key': k, 'server': m['server'], 'ts': ts, 'age': now - ts})
    if not items:
        return [], []

    keep = set()
    # самый свежий архив каждого сервера
    for server in {i['server'] for i in items}:
        keep.add(max((i for i in items if i['server'] == server), key=lambda i: i['ts'])['key'])
    # моложе 12 ч — все; дальше — самый свежий в окне
    best = {}
    for i in items:
        if i['age'] < KEEP_ALL_SEC:
            keep.add(i['key'])
            continue
        win = ('6h', i['ts'] // TIER1_WINDOW) if i['age'] < TIER1_UNTIL_SEC else ('12h', i['ts'] // TIER2_WINDOW)
        if win not in best or i['ts'] > best[win]['ts']:
            best[win] = i
    keep.update(i['key'] for i in best.values())
    # фиксированное число последних архивов каждого сервера (заменяет окна)
    keep_last = os.environ.get('PRUNE_KEEP_LAST')
    if keep_last:
        n = max(1, int(keep_last))
        keep = set()
        for server in {i['server'] for i in items}:
            own = sorted((i for i in items if i['server'] == server), key=lambda i: i['ts'], reverse=True)
            keep.update(i['key'] for i in own[:n])
    # жёсткий предел хранения (кроме самого свежего архива каждого сервера)
    max_age_days = os.environ.get('PRUNE_MAX_AGE_DAYS')
    if max_age_days:
        latest = {max((j for j in items if j['server'] == srv), key=lambda j: j['ts'])['key'] for srv in {j['server'] for j in items}}
        keep = {k for k in keep if k in latest or next(j for j in items if j['key'] == k)['age'] < float(max_age_days) * 86400}
    delete = sorted((i for i in items if i['key'] not in keep), key=lambda i: i['ts'])
    kept = sorted((i for i in items if i['key'] in keep), key=lambda i: i['ts'])
    return kept, delete


def main():
    cfg = os.environ.get('S3CFG', '/root/.s3cfg')
    bucket = os.environ['BUCKET_NAME']
    prefix = os.environ.get('PRUNE_PREFIX', 'mongodump/').rstrip('/') + '/'
    dry = os.environ.get('PRUNE_DRY_RUN') == '1'
    base = f's3://{bucket}/{prefix}'

    res = subprocess.run(['s3cmd', '-c', cfg, 'ls', '-r', base], capture_output=True, text=True)
    if res.returncode != 0:
        log(f"listing failed, nothing deleted: {res.stderr.strip()[-300:]}")
        return 0
    keys = []
    for line in res.stdout.splitlines():
        url = line.split()[-1] if line.strip() else ''
        if url.startswith(base):
            keys.append(url[len(base):])

    now = int(datetime.now(timezone.utc).timestamp())
    kept, delete = plan(keys, now)
    if not kept:
        log("no archives found, nothing deleted")
        return 0
    fmt = lambda i: f"{i['key']} ({(now - i['ts']) / HOUR:.1f} ч)"
    log(f"{'DRY RUN: ' if dry else ''}keep {len(kept)}, delete {len(delete)}")
    for i in delete:
        if dry:
            log(f"would delete {fmt(i)}")
            continue
        r = subprocess.run(['s3cmd', '-c', cfg, 'del', base + i['key']], capture_output=True, text=True)
        log(f"deleted {fmt(i)}" if r.returncode == 0 else f"delete failed {i['key']}: {r.stderr.strip()[-200:]}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
