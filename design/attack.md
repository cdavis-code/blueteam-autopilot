You can generate safe “attack” traffic by sending classic SQLi/XSS–looking requests against **your own WAF‑protected test domain**. WAF will log and (optionally) block them, and Agentic SOC will turn them into events. [alibabacloud](https://www.alibabacloud.com/help/en/security-center/getting-started/use-agentic-soc-quickly)

Below is a practical approach.

***

## 1. Preconditions

Make sure you have:

- A test domain (e.g., `ecs.muayid.com`) pointing to WAF in CNAME mode. [alibabacloud](https://www.alibabacloud.com/help/en/waf/web-application-firewall-3-0/getting-started/get-started-with-waf-3)
- WAF 3.0 active and protecting that domain. [alibabacloud](https://www.alibabacloud.com/help/en/waf/)
- WAF logging enabled to SLS and WAF configured as a data source in Agentic SOC (per quick‑start). [alibabacloud](https://www.alibabacloud.com/help/en/security-center/user-guide/log-integration-overview)

All traffic below should go to that **non‑production** domain only.

***

## 2. Simple manual “attacks” with curl

From your laptop, run a few HTTP requests with payloads that WAF’s built‑in rules recognize (SQL injection, XSS, directory traversal). [developer.aliyun](https://developer.aliyun.com/article/1333534)

### Example: SQL injection probes

```bash
# Basic SQLi-style query parameter (URL-encoded single quotes and spaces)
curl "http://ecs.muayid.com/?id=1%27%20OR%20%271%27%3D%271"

# UNION-based SQLi pattern
curl "http://ecs.muayid.com/products?search=abc%27%20UNION%20SELECT%20username%2Cpassword%20FROM%20users--"
```

### Example: XSS payloads

```bash
curl "http://ecs.muayid.com/search?q=%3Cscript%3Ealert(1)%3C%2Fscript%3E"
curl "http://ecs.muayid.com/profile?name=%3Cscript%3Ealert(1)%3C%2Fscript%3E"
```

### Example: Directory traversal

```bash
curl "http://ecs.muayid.com/download?file=..%2F..%2Fetc%2Fpasswd"
curl "http://ecs.muayid.com/assets?path=..%2F..%2F%2F..%2Fwindows%2Fwin.ini"
```

Even though your backend is just Nginx’s default page, WAF inspects the request line and parameters and should trigger its **predefined SQLi/XSS/path traversal rules**, generating WAF alerts and corresponding logs. [alibabacloud](https://www.alibabacloud.com/help/en/waf/web-application-firewall-3-0/use-cases/best-practices-for-pushing-api-security-alerts)

***

## 3. Slightly higher volume (still safe)

To make sure you get a few alerts/events, you can send several requests in a loop—just don’t go full DDoS:

```bash
for i in {1..20}; do
  curl -s "http://ecs.muayid.com/?id=1%27%20OR%20%271%27%3D%271" > /dev/null
  sleep 1
done
```

This is enough to create a pattern WAF will notice but won’t meaningfully stress a small ECS instance. [alibabacloud](https://www.alibabacloud.com/help/en/waf/web-application-firewall-3-0/getting-started/get-started-with-waf-3)

***

## 4. Verify in WAF and Agentic SOC

1. In **WAF console → Logs / Security Reports**, look for recent blocked or flagged requests for your domain; you should see entries tagged as SQLi/XSS/etc. [alibabacloud](https://www.alibabacloud.com/help/en/waf/web-application-firewall-3-0/use-cases/best-practices-for-pushing-api-security-alerts)
2. In **Security Center → Agentic SOC → Security alerts / Events**, wait a few minutes and then check for new events sourced from WAF. [alibabacloud](https://www.alibabacloud.com/help/en/security-center/user-guide/security-alert)

Once you see those, your MCP tools (`list_security_events`, `get_security_event_detail`, `list_alerts_for_event`) should start returning real data for your Autopilot agent.

***

## 5. Safety guidelines

- Only test against **your own** WAF‑protected test domain.  
- Keep request rates modest (tens, not thousands per second).  
- Avoid payloads that could accidentally invoke real actions on backend apps—in this case, your backend is just Nginx, so you’re safe, but keep this principle in mind for future tests.

If you tell me your actual test URL and which protection mode WAF is in (block / observe / CAPTCHA), I can suggest 3–4 very targeted curl commands tailored to your configuration to maximize the chance of generating clear, readable events for your demo.