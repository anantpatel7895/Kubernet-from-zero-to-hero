# 08 - Alertmanager

---

# Learning Objectives

* The division of labour between Prometheus and Alertmanager
* Grouping: group_by, group_wait, group_interval, repeat_interval
* Routing trees and matchers
* Inhibition and silences
* Receivers for Slack, email, PagerDuty
* How Alertmanager clusters (and why it is not like Prometheus)

---

# Who Does What

```text
Prometheus                      Alertmanager
──────────────────────────      ────────────────────────────
evaluates rules                 receives firing alerts
decides WHEN an alert fires     decides WHO is told, and HOW OFTEN
knows nothing about Slack       groups, deduplicates, silences, routes
                                sends the notification
```

Prometheus re-sends every firing alert to Alertmanager roughly every minute.
Alertmanager deduplicates them. So if Alertmanager restarts, nothing is lost
for long - the state is re-established on the next push.

---

# Grouping

A node dies. 60 pods go unready. Prometheus fires 60 alerts.

Without grouping: 60 Slack messages.
With grouping: one message listing 60 pods.

```yaml
route:
  group_by: ["alertname", "severity"]
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: default
```

| Setting | Meaning | Typical |
|---|---|---|
| `group_by` | labels that define a group | `["alertname", "cluster", "namespace"]` |
| `group_wait` | wait before the FIRST notification, to collect more alerts of the same group | 30s |
| `group_interval` | minimum gap before sending an UPDATE about a group that changed | 5m |
| `repeat_interval` | re-notify about a still-firing, unchanged group | 4h (1h for critical) |

```text
Timeline for a group:

  t=0      first alert arrives -> start group_wait
  t=30s    notification #1 sent (now includes any siblings that arrived)
  t=90s    a new alert joins the group
  t=5m30s  notification #2 sent (group_interval since the last one)
  t=4h30s  nothing changed, but repeat_interval elapsed -> reminder sent
```

### group_by: the two traps

```text
group_by: ["..."]            special value: group EVERYTHING into one.
                             Good for a tiny team, terrible at scale.

group_by: [alertname, pod]   effectively NO grouping - every pod is its
                             own group. You get 60 messages again.
```

Group by the labels that identify **the thing a human will go fix**, not by
the labels that make each alert unique.

---

# The Routing Tree

```yaml
route:
  receiver: default              # the fallback - the root always matches
  group_by: ["alertname", "severity"]

  routes:
  - matchers:
    - severity = "critical"
    receiver: critical
    repeat_interval: 1h

  - matchers:
    - severity = "info"
    receiver: "null"
```

```text
An alert walks the tree depth-first and stops at the FIRST matching node,
unless that node sets `continue: true`.

Child routes INHERIT group_by / intervals / receiver from the parent
unless they override them.
```

A realistic tree:

```yaml
route:
  receiver: slack-general
  group_by: ["alertname", "namespace"]
  routes:

  - matchers: [ team = "payments" ]
    receiver: slack-payments
    routes:
    - matchers: [ severity = "critical" ]
      receiver: pagerduty-payments

  - matchers: [ severity = "critical" ]
    receiver: pagerduty-oncall

  - matchers: [ severity = "info" ]
    receiver: "null"
```

Note how the labels in the alert rule (`team`, `severity`) are what makes
routing possible. **Labels route; annotations only describe.**

---

# Receivers

### Slack

```yaml
receivers:
- name: slack-general
  slack_configs:
  - api_url_file: /etc/alertmanager/secrets/slack-webhook   # never inline
    channel: "#alerts"
    send_resolved: true
    title: '{{ .Status | toUpper }} {{ .CommonLabels.alertname }}'
    text: >-
      {{ range .Alerts }}
      *{{ .Labels.namespace }}/{{ .Labels.pod }}*
      {{ .Annotations.description }}
      <{{ .Annotations.runbook_url }}|runbook>
      {{ end }}
```

### PagerDuty

```yaml
- name: pagerduty-oncall
  pagerduty_configs:
  - routing_key_file: /etc/alertmanager/secrets/pagerduty-key
    severity: '{{ .CommonLabels.severity }}'
```

### Email

```yaml
- name: email-ops
  email_configs:
  - to: ops@example.com
    from: alertmanager@example.com
    smarthost: smtp.example.com:587
    auth_username: alertmanager
    auth_password_file: /etc/alertmanager/secrets/smtp-password
```

### Webhook (what this project uses)

```yaml
- name: default
  webhook_configs:
  - url: http://localhost:9094/noop
    send_resolved: true
```

A webhook pointing nowhere still lets you see everything in the Alertmanager
UI, which is all a lab needs.

```text
Secrets: mount them as files and use the *_file variants.
A webhook URL in a ConfigMap in git is a credential leak.
```

---

# Inhibition

Suppress an alert when a more important related one is already firing.

```yaml
inhibit_rules:
- source_matchers:
  - severity = "critical"
  target_matchers:
  - severity = "warning"
  equal: ["alertname", "namespace"]
```

```text
source  -> if an alert matching this is FIRING...
target  -> ...suppress alerts matching this...
equal   -> ...but only where these labels are IDENTICAL on both.
```

The canonical example: a node is down (critical), so do not also page about
every pod on that node being unready (warning).

```text
Get `equal` wrong and you silence half your alerting without noticing.
Test inhibition rules deliberately.
```

---

# Silences

A silence is a **temporary, manual** mute. Created in the UI or via amtool,
not in config.

```bash
# Inside the alertmanager pod
amtool silence add \
  alertname=HighLatency namespace=monitoring \
  --duration=2h \
  --comment="planned DB migration, ticket OPS-1234" \
  --alertmanager.url=http://localhost:9093

amtool silence query --alertmanager.url=http://localhost:9093
amtool silence expire <id> --alertmanager.url=http://localhost:9093
```

```text
Silence   = temporary, manual, has an expiry and an author.
Inhibit   = permanent rule, automatic, based on another alert.
Deleting the rule = the alert was wrong and should not exist.

Never "fix" a noisy alert with an open-ended silence. That is how teams
end up blind.
```

---

# Clustering

Unlike Prometheus, Alertmanager **does** cluster properly:

```yaml
args:
- --cluster.listen-address=0.0.0.0:9094
- --cluster.peer=alertmanager-0.alertmanager:9094
- --cluster.peer=alertmanager-1.alertmanager:9094
```

Instances gossip over a mesh so that silences and "already notified" state are
shared, and you get **one** notification even though three Alertmanagers
received the same alert.

```text
Standard production setup:
  2-3 Prometheus servers  -> all point at ALL Alertmanagers
  3 Alertmanagers          -> clustered, deduplicating
```

Pointing each Prometheus at a single Alertmanager instead would mean losing
alerting whenever that one pod restarts.

---

# Hands On

```bash
# 1. Open the UI
open http://localhost:30093

# 2. Make the demo app fail until HighErrorRate fires
kubectl exec -n monitoring deploy/load-generator -- sh -c \
  'i=0; while [ $i -lt 600 ]; do curl -s -o /dev/null http://metrics-app:8000/error; i=$((i+1)); done'

# 3. Watch the state machine: Prometheus UI -> Alerts
#    inactive -> pending (yellow) -> firing (red)

# 4. The alert appears in Alertmanager after `for:` elapses.

# 5. Silence it, and watch it disappear from the active list.

# 6. Send a fake alert without touching Prometheus at all:
kubectl exec -n monitoring deploy/alertmanager -- \
  wget -qO- --header='Content-Type: application/json' \
  --post-data='[{"labels":{"alertname":"TestAlert","severity":"critical"}}]' \
  http://localhost:9093/api/v2/alerts
```

That last one is the fastest way to test a routing change: it exercises
Alertmanager without waiting for a real condition.

---

# Key Takeaways

```text
1. Prometheus decides WHEN; Alertmanager decides WHO and HOW OFTEN.
2. group_by collapses a storm into one notification - group by what a
   human will fix.
3. Routing is a depth-first tree; the first match wins unless continue: true.
4. LABELS route. Annotations only describe.
5. Inhibition is automatic suppression; silences are temporary and manual.
6. Alertmanager clusters by gossip - unlike Prometheus, HA is built in.
```

---

# Interview Questions

**Q: Why is Alertmanager a separate component?**
Separation of concerns: Prometheus evaluates conditions, Alertmanager handles
notification policy. It also lets many Prometheus servers share one
notification pipeline with consistent grouping and deduplication.

**Q: group_interval vs repeat_interval?**
`group_interval` is the minimum wait before sending an update about a group
whose membership changed. `repeat_interval` is how often to re-notify about a
group that has not changed at all.

**Q: Difference between a silence and an inhibition?**
A silence is manual, time-boxed, and created by a human for a known event. An
inhibition is a config rule that automatically suppresses one alert while a
related, more severe alert is firing.

**Q: How do you make Alertmanager highly available?**
Run 3 replicas with `--cluster.peer` gossip and point every Prometheus at all
of them; the cluster deduplicates so you still get one notification.
