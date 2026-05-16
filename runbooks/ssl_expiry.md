# Runbook: SSLCertExpiry

**Alert Name**: `SSLCertExpiryWarning` / `SSLCertExpiryCritical`  
**Severity**: Warning (<30 days) / Critical (<7 days)  
**Runbook Owner**: Platform SRE  
**Last Updated**: 2024-12-01

---

## Alert Description

An SSL certificate monitored by Blackbox Exporter is approaching its expiry date. At expiry, browsers will show security warnings and HTTPS connections will fail, causing a complete service outage.

---

## Likely Causes

1. Auto-renewal cron job (Certbot) has failed silently.
2. The certificate was issued manually and there is no auto-renewal configured.
3. The domain's DNS has changed, preventing ACME challenge completion.
4. The renewal process succeeded but Nginx/the server did not reload to pick up the new cert.

---

## Investigation Steps

### Step 1 — Check current certificate expiry directly

```bash
# Check expiry from the command line
echo | openssl s_client -connect <domain>:443 -servername <domain> 2>/dev/null \
  | openssl x509 -noout -dates

# Blackbox metric (days remaining)
curl -s "http://localhost:9115/probe?target=https://<domain>&module=http_2xx" \
  | grep ssl_earliest_cert_expiry
```

### Step 2 — Check Certbot auto-renewal status

```bash
# Check Certbot timer (systemd)
systemctl status certbot.timer

# Test renewal (dry run — does not renew)
sudo certbot renew --dry-run

# View renewal logs
sudo journalctl -u certbot -n 50
```

### Step 3 — Verify DNS is correct for the domain

```bash
# DNS resolution check
dig +short <domain> A

# Confirm it points to this VM's external IP
curl -s ifconfig.me
```

---

## Resolution

| Cause | Resolution |
|---|---|
| Auto-renewal failed | `sudo certbot renew --force-renewal` then reload web server |
| Certbot timer disabled | `sudo systemctl enable certbot.timer && sudo systemctl start certbot.timer` |
| DNS mismatch | Fix DNS records to point to the correct VM IP |
| Cert renewed but not loaded | `sudo nginx -s reload` or `sudo systemctl reload nginx` |
| No certbot installed | `sudo apt install certbot && sudo certbot --nginx -d <domain>` |

---

## Rollback / Escalation

- If cert expires before renewal completes: temporarily serve on HTTP while fixing, then re-enable HTTPS.
- Escalate to Engineering Lead if renewal cannot complete within 24 hours of a critical alert.
- For critical (<7 days): treat as P1 — work immediately regardless of business hours.
