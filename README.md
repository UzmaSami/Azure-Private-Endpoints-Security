
# 🔐 Azure Private Endpoints Security

## Overview
Complete Private Endpoint implementation securing 
Azure PaaS services from public internet access.
Built on existing Hub & Spoke network architecture.

*Engineer:* Uzma Sami 
*Region:* UK South  
*Architecture:* Hub & Spoke with dedicated PE subnet

## Architecture
![Architecture](docs/architecture-diagram.png)


## Overview

This project documents the design and
implementation of private network
connectivity for Azure PaaS services —
Key Vault, Storage Account, and SQL
Database — using Azure Private Endpoints,
Private DNS Zones, and network access
controls that eliminate public internet
exposure entirely.

The shift from infrastructure-as-a-service
to platform-as-a-service is one of the
most significant architectural changes
in cloud adoption. PaaS services offload
operational burden — no operating system
to patch, no infrastructure to manage,
no availability to engineer. The trade-off
that is frequently overlooked is that PaaS
services are by default publicly accessible
on the internet. A storage account, a key
vault, a SQL database — every one of them
has a public endpoint reachable from
anywhere in the world the moment it is
created.

This project removes that exposure
completely.

---

## The Problem This Solves

Consider what happens when a storage
account is created in Azure with default
settings. It receives a public DNS name
— accountname.blob.core.windows.net —
that resolves to a public IP address.
That address is reachable from any
internet-connected device in the world.
Authentication is required to access the
data — but authentication is the only
barrier. There is no network control
preventing an adversary from attempting
authentication from an anonymous server
anywhere on the internet. There is no
firewall rule blocking malicious traffic
before it reaches the authentication
layer. Credential attacks, token theft,
and misconfiguration exploitation all
become easier when the target is
publicly reachable.

The same applies to Key Vault — where
the organisation's secrets, certificates,
and encryption keys are stored. And to
SQL Database — where the organisation's
data lives.

The security model of relying solely on
authentication to protect publicly
accessible PaaS services is inadequate
for sensitive resources. Defence in depth
requires that network access be restricted
as a layer of control independent of and
in addition to authentication.

Private Endpoints solve this by giving
each PaaS service a private IP address
within the organisation's virtual network.
Traffic to the service stays within the
private network. The public endpoint can
be disabled entirely. An adversary
scanning the internet cannot see the
service exists. Authentication is still
required — but attackers cannot reach
the authentication layer from the
public internet.

---

## Architecture


AZURE VIRTUAL NETWORK
(Integrated with Hub-Spoke from Project 3)
═══════════════════════════════════════════════

rg-p4-data-security-uks
-│
-├── PRIVATE ENDPOINTS SUBNET
-│   snet-private-endpoints (10.1.4.0/24)
-│   NSG: deny-all inbound baseline
-│   │
-│   ├── pe-keyvault-uzmasami
-│   │   Private IP: 10.1.4.4
-│   │   Target: kv-security-uzmasami
-│   │   Subresource: vault
-│   │
-│   ├── pe-storage-uzmasami
-│   │   Private IP: 10.1.4.5
-│   │   Target: stuzmasamisecurity
-│   │   Subresource: blob
-│   │
-│   └── pe-sql-uzmasami
-│       Private IP: 10.1.4.6
-│       Target: sql-uzmasami-2026
-│       Subresource: sqlServer
-│
-├── PRIVATE DNS ZONES
-│   (Linked to VNet for name resolution)
-│   │
-│   ├── privatelink.vaultcore.azure.net
-│   │   A record: kv-security-uzmasami
-│   │   → 10.1.4.4 (private IP)
-│   │
-│   ├── privatelink.blob.core.windows.net
-│   │   A record: stuzmasamisecurity
-│   │   → 10.1.4.5 (private IP)
-│   │
-│   └── privatelink.database.windows.net
-│       A record: sql-uzmasami-2026
-│       → 10.1.4.6 (private IP)
-│
-└── PAAS SERVICES
 -   (Public access disabled)
  -  │
  -  ├── Key Vault
-    │   Public network access: DISABLED
    -│   Firewall: private endpoint only
    -│   Soft delete: 90 days
   - │   Purge protection: ENABLED
   - │
   - ├── Storage Account
   - │   Public blob access: DISABLED
   - │   Network access: private endpoint only
   - │   Minimum TLS: 1.2
   - │   Secure transfer: REQUIRED
   - │
   - └── SQL Database
       - Public endpoint: DISABLED
       - Network access: private endpoint only
       - TDE: ENABLED
       - Auditing: ENABLED → Log Analytics


---

## Why Private Endpoints Over
## Service Endpoints

Two Azure features restrict PaaS service
access to private networks — Service
Endpoints and Private Endpoints. They
are frequently confused. The distinction
matters significantly from a security
perspective.

Service Endpoints extend the virtual
network identity to the PaaS service.
Traffic from the VNet to the service
still uses the public endpoint — the
same publicly accessible IP address —
but Azure tags the traffic as originating
from the VNet and the service can be
configured to accept only VNet-tagged
traffic. The service remains reachable
on its public IP. DNS still resolves to
the public address. The restriction is
applied at the Azure network fabric
level but the attack surface of a
public IP remains.

Private Endpoints give the service a
private IP address inside the VNet.
DNS resolves to the private IP. Traffic
never leaves the private network.
The public endpoint can be disabled
completely — removing the publicly
accessible IP from the attack surface
entirely. An adversary scanning the
internet finds nothing. There is
nothing to find.

For Key Vault, Storage, and SQL — three
services that hold the organisation's
most sensitive assets — eliminating the
public attack surface entirely is the
correct choice. Private Endpoints are
the right tool. Service Endpoints are
an acceptable compromise in cost-
sensitive scenarios. They are not the
same security posture.

---

## Private DNS — The Critical Detail

Private Endpoints require careful DNS
configuration to function correctly
and this is where many implementations
break in ways that are difficult to
diagnose.

When a Private Endpoint is created for
a Key Vault, the key vault's DNS name
— kv-security-uzmasami.vault.azure.net
— must resolve to the private IP
address from within the VNet. By
default it resolves to the public IP
because that is what the public Azure
DNS records contain.

Private DNS Zones solve this. A Private
DNS Zone is created for the privatelink
subdomain of each PaaS service type.
An A record is created in the zone
mapping the service name to its private
endpoint IP. The zone is linked to the
VNet. When a resource in the VNet
queries DNS for the Key Vault name,
Azure DNS returns the private IP from
the Private DNS Zone rather than the
public IP from the public zone.

The failure mode when this is
misconfigured is subtle. The Private
Endpoint exists. The service is
configured with public access disabled.
But DNS still resolves to the public
IP. Traffic reaches the public endpoint.
The public endpoint rejects it. The
error message — connection refused or
access denied — looks like an
authentication or firewall problem
rather than a DNS problem. Diagnosing
it requires understanding the full
resolution chain.

I validated DNS resolution explicitly
using Resolve-DnsName from within the
VNet for each private endpoint before
proceeding. Confirming that each
service name resolved to its private
IP — not the public IP — was a
non-negotiable verification step.

---

## Key Vault Security Design

Key Vault is the most sensitive service
in this deployment. It stores the
secrets, connection strings, and
certificates that other services depend
on. Compromise of Key Vault is not a
partial breach — it is potentially
a complete one, because Key Vault
may hold the credentials needed to
access every other protected resource.

Beyond the Private Endpoint and
disabled public access, several
additional controls were applied.

Soft delete was configured with a
90-day retention period. Soft delete
means that deleted secrets, keys, and
certificates are not immediately
destroyed — they enter a deleted state
from which they can be recovered for
the retention period. This protects
against accidental deletion and against
adversaries who gain access and attempt
to destroy secrets to cause operational
disruption.

Purge protection was enabled. Without
purge protection an administrator can
permanently delete a soft-deleted
secret before the retention period
expires. With purge protection enabled
even an administrator cannot permanently
destroy secrets before the retention
period ends. This provides protection
against both malicious insiders and
supply chain attacks targeting
administrative accounts.

Role-Based Access Control was used
for Key Vault access rather than the
legacy Key Vault access policies model.
RBAC integration means that access to
Key Vault secrets is governed by the
same identity and access management
framework as all other Azure resources —
audited in the same place, reviewed
through the same Access Review process
configured in Project 2, and revokable
through the same mechanisms.

Diagnostic logging was enabled,
sending all Key Vault operations —
every secret access, every key
operation, every authentication attempt
— to the central Log Analytics
workspace. This data feeds Sentinel
analytics rules that alert on
anomalous access patterns such as
bulk secret enumeration or access
outside normal business hours.

---

## Storage Account Security Design

Storage accounts in Azure are
superficially simple. They hold blobs,
files, queues, and tables. Their
security complexity is disproportionate
to that apparent simplicity because
they are used for an enormous variety
of purposes — application data, backup
data, diagnostic logs, scripts, VHD
files — and are frequently
misconfigured.

The most common storage account
misconfiguration is enabled public
blob access. Public blob access allows
any blob container in the account to
be made publicly readable without
authentication. A developer who
creates a container and sets it to
public for testing purposes creates
a data exposure risk that may persist
indefinitely if there is no control
preventing it.

I disabled public blob access at the
account level. This is a blanket
control that prevents any container
in the account from ever being made
publicly accessible regardless of
container-level settings. Individual
container permissions cannot override
an account-level public access
prohibition.

Secure transfer was enforced —
requiring HTTPS for all access and
refusing HTTP connections. Minimum
TLS version was set to 1.2, deprecating
older TLS versions that have known
vulnerabilities.

Shared Access Signature tokens, which
provide time-limited delegated access
to storage resources, were configured
with the minimum permissions required
for each use case and the shortest
practical expiry time. Unlimited or
long-lived SAS tokens are a common
source of credential exposure when
they appear in application logs,
error messages, or accidentally
committed to source control.

---

## SQL Database Security Design

SQL Database introduces the data tier
— the layer where the most sensitive
business data typically resides. The
network isolation provided by the
Private Endpoint is the foundation
but not the entirety of the SQL
security configuration.

Transparent Data Encryption was
confirmed enabled. TDE encrypts the
database files at rest using a
database encryption key. This means
that physical access to the underlying
storage — which as a PaaS service is
Microsoft's responsibility — does not
yield readable data. The encryption
is transparent to applications — no
application code changes are required.

Azure Defender for SQL was enabled,
providing threat detection for
anomalous database access patterns —
SQL injection attempts, unusual query
patterns, access from unexpected
locations, and credential brute force.
Defender for SQL alerts feed into
Defender for Cloud and from there
into Sentinel, correlating database
threat signals with the broader
security picture of the environment.

SQL Auditing was configured to write
all database access events to the
central Log Analytics workspace.
Every connection, every query, every
failed authentication attempt is
recorded. This provides the forensic
record needed to investigate incidents
and the compliance evidence needed
to demonstrate that database access
is monitored.

Advanced Threat Protection was
configured with email alerting.
A SQL injection detection or
anomalous access alert generates
immediate notification — not a
record that sits in the portal
waiting to be discovered.

---

## Integration with Previous Projects

This project does not exist in
isolation. It integrates with and
depends upon the infrastructure
established in the preceding projects.

The Private Endpoint subnet was
added to the Spoke 1 VNet created
in Project 3. It inherits the NSG
baseline, the route table forcing
traffic through the hub firewall,
and the VNet peering that connects
it to the hub and to the on-premises
environment. The Private Endpoint
traffic is subject to the same
firewall inspection and flow logging
as all other traffic in the network.

Key Vault secrets are accessible from
the on-premises Domain Controller
because the DC can reach the private
endpoint through the hybrid connection
established in Project 0 — the gateway
transit configured in Project 3
enables this routing. This means
the ADSAE automation tool built in
Project 9 can securely retrieve
credentials from Key Vault rather
than storing them in script files.

Sentinel analytics rules created in
Project 5 reference Key Vault
diagnostic logs and SQL audit logs
collected in this project — enabling
detection of credential access and
data access anomalies in the same
SIEM that processes identity and
network events.

---

## Verifying Zero Public Exposure

After completing the implementation
I validated that public access was
genuinely eliminated — not just
configured to be eliminated.

For Key Vault I attempted to access
the vault using the Azure CLI from
outside the VNet — from my host
machine rather than from within the
virtual network. The connection was
refused. The vault was unreachable
from the public internet.

For the Storage Account I attempted
to access the blob endpoint from
outside the VNet. The connection
timed out — not rejected with a
403, but timed out entirely because
the public IP was not listening.

For SQL I attempted to connect using
SQL Server Management Studio from
outside the VNet with the public
endpoint disabled. The connection
failed with a timeout — again,
not an authentication failure but
a network-level failure because
the public endpoint was not
accepting connections.

These negative validation tests —
confirming that what should be
blocked actually is blocked — are
as important as the positive
validation tests confirming that
authorised access works correctly.
A control that is configured but
not verified provides false assurance.

---

## Challenges Encountered

*DNS resolution from on-premises*

The Private DNS Zones are linked to
the Azure VNet. DNS queries from
within the VNet resolve correctly
to private IP addresses. DNS queries
from the on-premises Domain Controller
do not automatically use the Private
DNS Zones — they use the on-premises
DNS server which has no knowledge
of the privatelink zones.

I resolved this by configuring a
conditional forwarder on the Domain
Controller's DNS server for each
privatelink zone, forwarding queries
to the Azure DNS resolver at
168.63.129.16. This IP is the Azure
DNS resolver address — it is only
reachable from within an Azure VNet
or from on-premises networks connected
to Azure. With the conditional
forwarder in place, on-premises
resources resolve PaaS service names
to private IPs correctly.

This is a detail that is frequently
missed in hybrid Private Endpoint
deployments and results in on-premises
applications being unable to reach
Azure PaaS services through private
endpoints even when Azure-hosted
resources can reach them perfectly.

**SQL firewall rules and private
endpoint interaction**

When a SQL server has both a private
endpoint and a firewall configured,
the firewall rules apply to public
endpoint traffic only. Private endpoint
traffic bypasses the firewall rules
entirely. This meant that the firewall
rule allowing Azure services to connect
was irrelevant once the private
endpoint was in use — only resources
that could route to the private
endpoint IP could connect. Understanding
this interaction was necessary to
correctly validate the access control
configuration.

---

## Lessons Learned

The most significant lesson from this
project was that private endpoint
DNS is the most common failure point
in private endpoint deployments and
the hardest to diagnose when it fails.
DNS troubleshooting in Azure requires
understanding the resolution hierarchy
— VNet DNS settings, Private DNS Zone
links, conditional forwarders, and
Azure DNS resolver behaviour — and
being systematic about isolating where
in that chain a resolution failure
is occurring.

The second lesson was about the
importance of negative testing. Every
control was validated both positively
— confirming authorised access works
— and negatively — confirming
unauthorised access fails. Security
implementations that are only tested
positively provide uncertain assurance.
If a configuration change silently
re-enables public access the positive
test will still pass. Only the negative
test will catch it.

The third lesson concerned the
relationship between PaaS security
and development workflows. Disabling
public access to PaaS services
immediately affects any developer or
tool that was using the public
endpoint. Deployments, CI/CD pipelines,
monitoring tools, and management scripts
all require updating to route through
the private endpoint. This is not a
technical problem — it is an
organisational change management
problem that requires advance
communication and a migration plan.

---

## What I Would Do Differently at Scale

At enterprise scale I would implement
Azure Policy to enforce private
endpoint requirements automatically.
A policy in deny effect that prevents
creation of storage accounts with
public access enabled, or Key Vaults
without private endpoints, ensures
that the security baseline is enforced
at resource creation rather than
relying on post-deployment
configuration.

I would also implement Private DNS
Zone management through Azure Policy
using the DeployIfNotExists effect —
automatically creating the required
DNS records when a private endpoint
is deployed, removing the manual
DNS configuration step that is
frequently missed.

Customer-managed keys for encryption
would replace the default Microsoft-
managed keys for Key Vault and Storage
Account encryption at rest, giving
the organisation control over the
encryption key lifecycle and the
ability to immediately revoke data
access by revoking the key — a
requirement in highly regulated
industries.

---

Uzma Shabbir
Azure Security Engineer | AZ-104 | AZ-500
[GitHub](https://github.com/UzmaSami) •
[LinkedIn](https://linkedin.com/in/uzma-shabbir-034361128)

