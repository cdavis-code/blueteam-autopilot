# Threat Intel/Whitelists File

## Why it's useful: Tests your agent's edge-case reasoning to make sure it doesn't block friendly traffic.

Sample Context: A list of corporate office IP ranges or uptime monitors. If an attack comes from a corporate VPN IP, the agent can flag it as a "Potential Compromised Internal Asset" rather than simply blacklisting it blindly.