|               | Deployment Selector       | Service Selector                 |
| ------------- | ------------------------- | -------------------------------- |
| Purpose       | Manage Pods               | Send traffic to Pods             |
| Used by       | Deployment controller     | Service                          |
| Matches       | Pod labels                | Pod labels                       |
| Main question | "Which Pods do I manage?" | "Which Pods receive my traffic?" |
| Example       | `app: ml-api`             | `app: ml-api`                    |
