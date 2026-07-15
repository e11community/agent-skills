# Bastion VM for `/sql-proxy`

A minimal IAP bastion that `/sql-proxy` tunnels through to reach a **private-IP-only** Cloud SQL for
PostgreSQL instance. **No public IP** — reached only via IAP TCP forwarding. Each developer runs their
own Cloud SQL Auth Proxy on it under their own identity, so the bastion itself needs no DB privileges.

Assumes Private Service Access (the Cloud SQL private-IP peering) lives on the **`default`** VPC (the
e11 convention). Because PSA peering is a property of the VPC, any subnet in it — including the bastion's
— reaches the instance's private IP over the auto-imported peering route, with no extra config.

## Terraform

```hcl
variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "zone" {
  type    = string
  default = "us-central1-a" # /sql-proxy assumes ${region}-a by default
}

variable "dev_group" {
  type        = string
  description = "Developers allowed to tunnel, e.g. group:bastion-developers@engineering11.com"
}

# Default VPC + regional subnet. PSA peering on this VPC gives the bastion a route to the private IP.
data "google_compute_network" "default" {
  name = "default"
}

data "google_compute_subnetwork" "default" {
  name   = "default"
  region = var.region
}

# Built-in compute service account — the proxy authenticates as the *developer's* ADC, not this SA,
# so it needs NO Cloud SQL roles.
data "google_compute_default_service_account" "default" {}

# IAP TCP forwarding -> SSH. IAP always originates from this fixed range; scope by the bastion tag.
resource "google_compute_firewall" "iap_ssh" {
  name          = "allow-iap-ssh-bastion"
  network       = data.google_compute_network.default.id
  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"] # Google IAP range
  target_tags   = ["bastion"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_instance" "bastion" {
  project      = var.project_id
  name         = "bastion"
  zone         = var.zone
  machine_type = "e2-small" # modest: 2 shared vCPU / 2 GB — fine for a few per-dev proxies

  labels = { bastion = "true" } # /sql-proxy discovers the bastion by labels.bastion=true
  tags   = ["bastion"]          # matches the IAP-SSH firewall rule above

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
    }
  }

  # No access_config block => no external IP. Reached only through IAP.
  network_interface {
    network    = data.google_compute_network.default.id
    subnetwork = data.google_compute_subnetwork.default.id
  }

  service_account {
    email  = data.google_compute_default_service_account.default.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    enable-oslogin = "TRUE" # SSH via OS Login; maps IAM identities to Linux users
    user-data      = <<-EOT
      #cloud-config
      write_files:
        # `ssh -L localport:<remote unix socket>` is sshd "stream-local" forwarding; enable it (and TCP
        # forwarding) in case the image hardened them off. NOTE: no kernel net.ipv4.ip_forward / NAT is
        # needed — `-L` forwarding is sshd userspace, not IP routing (that's only for VPN/subnet-router
        # patterns we deliberately avoid).
        - path: /etc/ssh/sshd_config.d/60-forwarding.conf
          content: |
            AllowTcpForwarding yes
            AllowStreamLocalForwarding yes
      runcmd:
        # Install the Cloud SQL Auth Proxy v2 into the OS. (gcloud ships on GCE's Ubuntu/Debian images.)
        - curl -fsSL -o /usr/local/bin/cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.23.0/cloud-sql-proxy.linux.amd64
        - chmod +x /usr/local/bin/cloud-sql-proxy
        - systemctl reload ssh || systemctl reload sshd || true
    EOT
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
}

# --- Roles that make tunneling work (grant to your developer group) ---

# OS Login SSH to a VM with an attached SA requires "act as" on that SA. Easy to miss; SSH fails
# without it.
resource "google_service_account_iam_member" "devs_actas_bastion_sa" {
  service_account_id = data.google_compute_default_service_account.default.name
  role               = "roles/iam.serviceAccountUser"
  member             = var.dev_group
}

# Open the IAP tunnel to the VM.
resource "google_project_iam_member" "devs_iap" {
  project = var.project_id
  role    = "roles/iap.tunnelResourceAccessor"
  member  = var.dev_group
}

# Log in over OS Login.
resource "google_project_iam_member" "devs_oslogin" {
  project = var.project_id
  role    = "roles/compute.osLogin"
  member  = var.dev_group
}
```

## Notes

- **Reaching the PSA range:** nothing special — the bastion is in the VPC that holds the PSA peering, so
  the peering route to the Cloud SQL private IP is auto-imported. (If your PSA peering is on a VPC other
  than `default`, point the network/subnetwork data sources at that VPC instead.)
- **The compute SA needs no DB roles.** The proxy runs as each developer's ADC (per-user
  `gcloud auth application-default login` on the bastion), so all DB access is audited to the individual
  and the SA stays least-privilege. The three role bindings above are for the *developers*, not the SA
  (they're the pieces of the `BastionDeveloper` custom role).
- **"Advanced networking" = sshd forwarding, not kernel IP forwarding.** The tunnel is `ssh -L` to a Unix
  socket, handled by sshd in userspace — so `AllowStreamLocalForwarding`/`AllowTcpForwarding` are the
  only toggles. Do **not** enable `net.ipv4.ip_forward`/NAT; that's for VPN/subnet-router designs this
  intentionally avoids.
- **Sizing:** `e2-small` (2 GB) comfortably runs a handful of concurrent per-developer proxies + gcloud.
  Drop to `e2-micro` for very light use; bump up if many devs connect at once.
- **Region/zone:** put the bastion in the instance's region; `/sql-proxy` defaults the zone to
  `${region}-a` (overridable with `--zone`).
