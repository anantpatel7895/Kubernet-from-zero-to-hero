📊 POD NAMING COMPARISON
═══════════════════════════════════════════════════════════════

DEPLOYMENT PODS (Random Names):
────────────────────────────────
storage-demo-568689c955-6lqzq
             ↑          ↑
             │          └── Random 5-char suffix
             └── ReplicaSet hash (changes on update)

Pattern: <deployment>-<replicaset-hash>-<random>
Predictable? NO ❌
Stable after restart? NO ❌


STATEFULSET PODS (Ordered Names):
──────────────────────────────────
stateful-storage-demo-0
                      ↑
                      └── Ordinal index (0, 1, 2, ...)

Pattern: <statefulset>-<ordinal>
Predictable? YES ✅
Stable after restart? YES ✅

═══════════════════════════════════════════════════════════════

KEY INSIGHT:
Both create PODS, but:
• Deployment pods = Temporary, interchangeable workers
• StatefulSet pods = Permanent, unique specialists