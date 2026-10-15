# cs-haproxy-spoa-bouncer

CrowdSec's HAProxy SPOA bouncer built from source, one static binary on
`scratch`, with GeoLite2. HAProxy's SPOE filter asks it, per connection
and request, for a remediation (allow, ban, captcha). It answers from
the bans it pulls from a CrowdSec Local API (LAPI) and, if configured,
from AppSec. Together, the bouncer and HAProxy are **fail-open**: every
failure ends in allow. Runtime contract: the Containerfile's header.
Sources and the reason for each choice: [REFERENCES.md](REFERENCES.md).

## Fail-open

A change keeps every failure ending in allow, on both sides:

- **The bouncer** serves SPOA from start, before its first pull succeeds
  (`retry_initial_connect: true`), and answers allow until a ban
  arrives. Pulled bans stay while the LAPI is down. AppSec errors and
  timeouts allow. A GeoLite2 path to a missing file turns the country
  lookups off, and the bouncer serves on.
- **HAProxy** allows when the bouncer is down, restarting, or slower
  than `timeout processing`:
  - frontend rules act on an explicit `var(txn.crowdsec.remediation)`
    (`ban`, `captcha`), as upstream's `config/haproxy.cfg`;
  - the agents' backend is health-checked (`check inter 1s`), with a
    `timeout connect` of about 100ms, so a dead agent fails fast;
  - `option continue-on-error` in the SPOE file keeps the HTTP messages
    (AppSec) after a failed TCP one;
  - a liveness probe on 9000/tcp is the bouncer's only probe: a
    readiness or startup probe would gate HAProxy on it.

## Rules

- Keep `retry_initial_connect: true`: `false` exits when the first pull
  fails, a crash loop while the LAPI is down.
- The environment carries the LAPI's URL and key (`CROWDSEC_URL`,
  `CROWDSEC_KEY`); every other setting is an override in `.yaml.local`.
- Ship the datalists `geolite2/` folder whole: the three databases.
- The server test is the gate: Renovate automerges on it. A change to
  the shipped config passes it.

## Updates

- **Releases:** Renovate follows upstream's tags and automerges patch
  and minor. For a major, diff the two tags
  (`https://github.com/crowdsecurity/cs-haproxy-spoa-bouncer/compare/v<old>...v<new>`):
  `config/crowdsec-spoa-bouncer.yaml` against the shipped config, the
  `Makefile`'s `binary` target against the build, and
  `config/crowdsec.cfg`, HAProxy's side, which the test leaves out (it
  sends `crowdsec-tcp` only). A deployment bumping its tag diffs
  `config/crowdsec.cfg` too.
- **GeoLite2:** Renovate moves the datalists digest (the `lists` stage's
  `FROM`) with haproxy's each time datalists is pushed, and automerges
  it on the server test. A red test means the databases changed: fix
  the lookup or `containers/datalists`.

## Limits

- Bans live in memory: a restart while the LAPI is down starts with
  none.
- A decision without `origin` or `scope` crashes the bouncer
  (`pkg/dataset/root.go`, unchecked pointers); it restarts while HAProxy
  allows.
- An override with a GeoLite2 path the container lacks turns every
  country lookup off, silently.
- The Lua scripts and HTML templates serve HAProxy (`lf-file`): HAProxy
  in another container reads them through a volume of this image (a
  Kubernetes image volume, a compose named volume).
