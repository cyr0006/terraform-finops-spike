# Decisions and Incidents

This file records the main problems I hit while building this spike, and the choices I made on purpose. Each entry explains what happened or what was decided, why, and what it cost or saved.

The format is loosely based on Architecture Decision Records (ADRs).

## Summary

### Incidents

| #   | Incident                                           | Impact                                                         | Fix                                                       |
| --- | -------------------------------------------------- | -------------------------------------------------------------- | --------------------------------------------------------- |
| I1  | Terraform lost track of an EC2 instance            | An orphaned instance kept running and billing                  | Terminated it by hand; moved state to S3 later            |
| I2  | Instance got a public IP despite being told not to | Extra $0.005/hour, and every apply would recreate the instance | Set `subnet_id` explicitly                                |
| I3  | Cost allocation tags blocked in my account         | Could not split costs by tag                                   | Took control of the AWS Organization's management account |
| I4  | Infracost hung forever on one project              | Cost scan never finished                                       | Isolated the cause and worked around it                   |

### Decisions

| #   | Decision                               | Why it matters                                                 |
| --- | -------------------------------------- | -------------------------------------------------------------- |
| D1  | Budget measures cost before credits    | Credits would otherwise hide real usage as I've 100+ credits   |
| D2  | Guardrails in their own Terraform root | Destroying the spike does not remove the safety net            |
| D3  | Anomaly detection as well as a budget  | Catches unusual spend, not just a fixed limit                  |
| D4  | `default_tags` on the AWS provider     | Every resource is tagged for cost allocation automatically     |
| D5  | Default VPC, no public IP              | Avoids about $3.60/month per instance for an IP we do not need |
| D6  | Own storage and compute modules        | Cost and security settings built in once and reused            |
| D7  | Pin the Availability Zone              | Keeps plans stable, avoids surprise replacements               |
| D8  | Remote state in S3 with native locking | State is shared, versioned and protected from concurrent runs  |
| D9  | Rightsize to Graviton (`t4g.micro`)    | About 20% cheaper instance, checked before applying            |

---

## Incidents

### I1. Terraform lost track of an EC2 instance

**What happened**
After a few rounds of `apply` and `destroy` while following the tutorial, the EC2 console showed two terminated instances and one still running. The running one had my `Name` tag and settings, so this project had created it. But `terraform destroy` had not removed it, and it was not in my state file.

**Cause**
Terraform only manages resources recorded in its state file. The state file maps each resource in the code to a real AWS resource ID. If an instance is created but never recorded, or the record is lost, Terraform cannot see it. It will not destroy it, and the next `apply` creates another one next to it.

I forget the exact trigger, but I suspect it was from me changing a linux image at some stage (As I was initially following HashiCorp tutorial)

The two terminated instances were expected. Changing the AMI (Ubuntu to Amazon Linux) and moving the instance into a new VPC both force Terraform to replace the instance, so the old ones were terminated correctly.

**Fix**
Terminated the orphan with the AWS CLI.

**Lessons**

- State is the link between the code and what really exists. Losing it can mean duplicate resources and orphans that keep billing.
- `terraform state list` shows what Terraform is tracking. If the console shows more than that, something has been orphaned.
- Read every plan for `must be replaced` and check the `X to add, Y to destroy` line.
- This is the main reason for moving state to S3 (D8).

---

### I2. Instance got a public IP despite `associate_public_ip_address = false`

**What happened**
The compute module set `associate_public_ip_address = false`, and the plan showed `false`. After `apply`, the instance had a public IPv4 address anyway. Running `plan` again showed:

```
# module.compute.aws_instance.this must be replaced
  ~ associate_public_ip_address = true -> false # forces replacement
```

**Cause**
No `subnet_id` was set, so AWS put the instance in a default subnet. Default subnets give every instance a public IP. The AWS provider only sends `associate_public_ip_address` to AWS when a subnet is also specified, so my setting was silently dropped and the subnet's default won.

**Why it mattered**

- Public IPv4 addresses cost $0.005/hour (about $3.60/month), over a third of the instance's own cost.
- Every `apply` would destroy and recreate the instance, and the new one would get a public IP again. The plan would never settle.

**Fix**
Looked up the default subnet for one Availability Zone with a `data "aws_subnet"` block and passed it in as `subnet_id`. The instance was replaced once, and the next plan showed `No changes`.

**Lessons**

- A plan shows what Terraform intends to do, not what AWS will actually do. Check the real resource after applying, especially for anything billable.
- Run `plan` again after `apply`. A healthy setup shows `No changes`.
- Defaults are where hidden costs come from. The default VPC is built for convenience, not cost.

---

### I3. Cost allocation tags blocked in my account

**What happened**
`aws ce list-cost-allocation-tags` failed with:

```
Linked account doesn't have access to cost allocation tags.
```

**Cause**
My account turned out to be a member account inside an AWS Organization. In an Organization, only the management (payer) account can activate cost allocation tags. The management account was controlled by AWS, not by me.

**Fix**
Upgraded the account from the Free plan to the Paid plan and enabled the Organization's advanced features, which gave me control of the management account. Activated the four tags (`Owner`, `CostCentre`, `Environment`, `Project`) there.

**Trade-off**
On the Paid plan, usage beyond the promotional credits is charged to my card. The budget (D1) alerts on real usage from the first dollar to cover this. The management account also needs MFA and should not run any workloads.

**Lessons**

- This mirrors how large companies are set up: many member accounts, with billing controlled centrally in the management account.
- Tags only apply to costs from the moment they are activated, and only show up after AWS has seen them on resources. Companies activate them before teams start deploying, otherwise early spend shows up as untagged.

---

### I4. Infracost hung forever on one project

**What happened**
`infracost scan` (version 2.20) ran for minutes without finishing. It also left background processes running at full CPU after being stopped.

**How I found the cause**
Infracost scans every Terraform project under the given path, so I scanned each folder on its own and then tried different combinations of files:

| Test                                          | Result         |
| --------------------------------------------- | -------------- |
| `bootstrap/`                                  | Finished in 6s |
| Root project                                  | Finished in 7s |
| `guardrails/`                                 | Hung           |
| `guardrails/` without `terraform.tfvars`      | Finished in 5s |
| `guardrails/` with a dummy `terraform.tfvars` | Hung           |

Any project containing a `terraform.tfvars` file made the Terraform parser loop forever. It was not caused by my code or the values in the file.

**Fix**
Stopped the leftover processes, moved `terraform.tfvars` out of the repo temporarily while scanning, then moved it back. It was moved outside the repo rather than renamed, because a renamed file like `terraform.tfvars.bak` would not match `.gitignore` and could be committed with my email in it.

**Lessons**

- Narrow the problem down by testing one change at a time.
- Workarounds can create new risks. Check that a temporary file move cannot leak secrets into git.

---

## Decisions

### D1. Budget measures cost before credits

**Context**
The account has $100 in promotional credits. By default, AWS Budgets measures cost after credits, so real usage shows as $0 until the credits run out.

**Decision**
A $15/month budget with `include_credit = false`, written in Terraform. Email alerts at 50% and 80% of actual spend, and at 100% of forecast spend.

**Why**
FinOps cares about what is being consumed, not just what is paid. The forecast alert warns before the limit is reached, not after.

**Cost**: free.

---

### D2. Guardrails in their own Terraform root

**Context**
The budget and anomaly monitor should outlive the spike's EC2 and S3 resources.

**Decision**
Put them in a separate folder (`guardrails/`) with its own state.

**Why**
Running `terraform destroy` in the main project cannot remove them. Grouping resources by how long they live is a common pattern in larger codebases.

---

### D3. Anomaly detection as well as a budget

**Context**
A budget only alerts when total spend crosses a fixed line.

**Decision**
Added a Cost Anomaly Detection monitor per AWS service, with a daily email for anomalies of $1 or more.

**Why**
Anomaly detection learns normal spend and flags unusual patterns, and it names the service responsible. In a large account, a monthly budget might not fire for weeks after something goes wrong.

**Trade-offs**
It needs about 10 days of history before it can detect anything, so it mostly protects the account after the spike. Real teams set much higher thresholds to avoid alert fatigue.

**Cost**: free.

---

### D4. `default_tags` on the AWS provider

**Decision**
Set `Owner`, `CostCentre`, `Environment` and `Project` once in the provider block of every root.

**Why**
Every resource gets the tags automatically, so none can be forgotten. Checked after applying: the EC2 instance, its root volume and the S3 buckets all received them.

**Related**
Companies also enforce tagging with tag policies, Service Control Policies and policy-as-code checks on pull requests. Infracost's example tagging policy flagged my lowercase `sandbox` value, which shows why consistent tag values matter as much as the keys.

---

### D5. Default VPC and no public IP

**Context**
I had earlier added the community VPC module to learn how modules work.

**Decision**
Removed it and used the default VPC. The instance has no public IP.

**Why**
The spike is about cost, not networking. Nothing needs to connect to the instance; it only needs to exist so its cost can be measured. A public IPv4 address would add about $3.60/month.

**Trade-off**
The instance cannot be reached from outside. In a company it would normally sit in a private subnet and be accessed through SSM Session Manager instead of SSH.

---

### D6. Own storage and compute modules

**Decision**
Wrote two local modules:

- `modules/storage`: an S3 bucket with public access blocked, encryption, versioning and a lifecycle rule.
- `modules/compute`: one EC2 instance with an encrypted 8 GB gp3 root volume.

**Cost controls built in**

- **Lifecycle rule:** versioning keeps every overwritten or deleted file, and each version is billed in full. Old versions are deleted 30 days after being replaced. Objects move to Infrequent Access after 30 days, and failed partial uploads are cleaned up after 7 days.
- **Instance type allow-list:** validation only accepts `t3.micro`, `t3.small`, `t4g.micro` and `t4g.small`, so a typo cannot launch an expensive instance.
- **`delete_on_termination = true`:** the disk is deleted with the instance, so no unattached volumes are left billing.
- **Architecture from instance type:** a `locals` value picks the ARM image for Graviton types and the x86 image otherwise. This made D9 a one-line change.

**Trade-off**
`force_destroy = true` on the data bucket lets `destroy` delete it with files inside. Acceptable for a spike, not for production.

---

### D7. Pin the Availability Zone

**Decision**
The compute module looks up the default subnet in one fixed Availability Zone (`ap-southeast-2a`), set by a variable.

**Why**
If Terraform picked "any default subnet" and the choice changed between runs, the instance would be replaced. A fixed AZ keeps plans stable.

---

### D8. Remote state in S3 with native locking

**Context**
State was a local file on my laptop. That is the root cause of I1, and it cannot be shared with a team.

**Decision**

- A separate `bootstrap/` folder creates the state bucket. It has versioning, encryption, public access blocked and `prevent_destroy`, and its name includes the account ID so it is unique and predictable.
- The main project uses an S3 backend with `use_lockfile = true`, and the state was moved with `terraform init -migrate-state`.

**Why**

- **Shared and durable:** the state no longer depends on one laptop.
- **Versioned:** a bad or corrupted state can be rolled back.
- **Locked:** a lock file stops two runs from changing the state at the same time. Before 2024, S3 could not do the "create only if it does not exist" step a lock needs, so teams used a DynamoDB table for locking. Terraform 1.10 added native S3 locking.

**Trade-offs**

- The bootstrap folder's own state is still local. The bucket cannot store the state that created it. This is the usual chicken-and-egg problem, and the predictable name means the state could be rebuilt with `terraform import` if needed.
- Backend settings cannot use variables. Teams that deploy the same code to several environments use partial backend configuration (`terraform init -backend-config=...`).

**Cost**: a few cents per month.

---

### D9. Rightsize to Graviton

**Context**
`infracost scan` estimated $10.40/month and recommended switching from `t3.micro` to `t4g.micro`.

**Decision**
Changed the instance type, checked the cost with `infracost diff` before applying, then applied.

|                             | Hourly  | Monthly                  |
| --------------------------- | ------- | ------------------------ |
| `t3.micro` (x86)            | $0.0132 | $9.64                    |
| `t4g.micro` (Graviton, ARM) | $0.0106 | $7.74                    |
| Saving                      |         | $1.90/month, $22.78/year |

The total dropped 18% rather than 20% because the disk cost stays the same.

**Trade-offs**

- Moving from x86 to ARM needs a different AMI, so the instance was replaced, not resized in place.
- In production, software and container images must support ARM, so a change like this is usually tested in dev first.

**Why it matters**
$2/month is small here. The same change across 2,000 instances is roughly $45,000/year with no change in capacity. Infracost found it from the code alone, before anything was deployed. In a team, this runs on every pull request and posts the cost change as a comment.

---

## Known gaps

- **S3 SSL-only policy:** Infracost flagged that both buckets should deny non-HTTPS requests (AWS Security Hub check S3.5). Not added yet.
- **AMI lookup uses `most_recent = true`:** when Amazon publishes a new image, the next plan will want to replace the instance. Real teams pin the AMI or ignore AMI changes.
- **Infracost is not in CI:** scans are run by hand.
