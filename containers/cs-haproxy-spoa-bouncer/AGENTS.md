# cs-haproxy-spoa-bouncer

CrowdSec's HAProxy SPOA bouncer, one static Go binary built from source
on `scratch`. HAProxy's SPOE filter asks it what to do with each
connection and request (allow, ban, captcha, challenge), from the bans
it pulls from a CrowdSec Local API (LAPI, not in this repository) and,
if configured, CrowdSec's AppSec. Its config fails open: traffic flows
when the bouncer or the LAPI is down. Runtime contract: the
Containerfile's header. Upstream sources and the reason for each
choice: [REFERENCES.md](REFERENCES.md).

## Fail-open

Every failure ends in "allow", on two sides:

- **The bouncer** serves SPOA without the LAPI
  (`retry_initial_connect: true`): no decision yet means allow. Once
  pulled, bans stay while the LAPI is down. An AppSec timeout or error
  allows the request. A missing GeoIP database disables the geo checks.
- **HAProxy** must allow when the bouncer doesn't answer (down,
  restarting, slower than `timeout processing`). In the frontend, rules
  act only on an explicit `var(txn.crowdsec.remediation)` (`ban`,
  `captcha`), never on its absence, as upstream's `config/haproxy.cfg`.
  Shorter waits than upstream's: the agents' backend health-checked
  (`check inter 1s`) with a `timeout connect` of about 100ms, so a dead
  agent fails fast. `option continue-on-error` in the SPOE file keeps
  the HTTP messages (AppSec) after a failed TCP one.

No readiness or startup probe gates HAProxy on the bouncer: a liveness
probe on 9000/tcp at most.

## Rules

- Keep `retry_initial_connect: true`: without it the bouncer exits when
  the first pull fails, a crash loop while the LAPI is down.
- `api_url` and `api_key` come from `CROWDSEC_URL` and `CROWDSEC_KEY`;
  no other setting from the environment.
- The server test checks fail-open at start (LAPI down: allow), a ban
  once the LAPI is up, and the ban kept when it goes down again. A
  change to the shipped config passes it.

## Updates

Renovate follows upstream's tags, automerged for patch and minor on the
server test. Before merging a major, compare upstream's
`config/crowdsec-spoa-bouncer.yaml` and `config/crowdsec.cfg` between the
two tags
(`https://github.com/crowdsecurity/cs-haproxy-spoa-bouncer/compare/v<old>...v<new>`),
and the build against the `binary` target of the `Makefile`. The test
sends only `crowdsec-tcp`: a deployment bumping its tag compares
`config/crowdsec.cfg` too, for HAProxy's side.

## Limits

- A restart while the LAPI is down starts with no ban: bans live in
  memory only.
- A decision without `origin` or `scope` crashes the bouncer
  (`pkg/dataset/root.go`, unchecked pointers): it restarts, and HAProxy
  allows meanwhile.
- The Lua scripts and HTML templates serve HAProxy (`lf-file`), not the
  bouncer: HAProxy in another container reads them through a volume of
  this image (a Kubernetes image volume, a compose named volume).
