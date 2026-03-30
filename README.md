# RequestAADRefreshToken2

A patched and extended C# implementation of [Lee Christensen's RequestAADRefreshToken](https://github.com/leechristensen/RequestAADRefreshToken), updated for modern Azure AD authentication requirements.

Requests a PRT cookie from an Azure AD joined device by calling the `IProofOfPossessionCookieInfoManager` COM interface directly inside `MicrosoftAccountTokenProvider.dll` — the same mechanism used by Chrome and Edge for browser SSO.

---

## Background

The original tool was published in July 2020 and stopped working for token exchange after Microsoft enforced a nonce requirement in October 2020. Cookies without an embedded `request_nonce` are rejected by the AAD token endpoint. This version fixes that and adds several improvements.

---

## Changes Over the Original

| # | Issue | Fix |
|---|---|---|
| 1 | CLSID stored as string in metadata — caught by Defender | CLSID reconstructed from integer literals at runtime via `Type.GetTypeFromCLSID()` |
| 2 | Identifying namespace and class names in metadata — flagged by AMSI | All names replaced with generic alternatives |
| 3 | Stride bug in unmanaged array walk — wrong struct size corrupts pointer on multi-cookie responses | Fixed to use unmanaged struct size for pointer arithmetic |
| 4 | No nonce support — cookie uses `iat` timestamp, rejected by AAD since Oct 2020 | Nonce accepted via `--nonce` flag or auto-fetched from AAD |

---

## Requirements

- Windows 10 / 11
- .NET Framework 4.7+ or .NET 6+
- Must run in the context of an Azure AD user on an **Azure AD joined** or **Hybrid joined** device
- `AzureAdPrt: YES` in `dsregcmd /status`

---

## Usage

```
RequestAADRefreshToken2.exe [options] [url]
```

### Options

| Flag | Description |
|---|---|
| `--nonce`, `-n <value>` | Use a specific nonce obtained externally |
| `--tenant`, `-t <value>` | Tenant ID or domain for nonce auto-fetch (default: `common`) |
| `-legacy` | No nonce - uses `iat` timestamp (broken since Oct 2020, warns) |
| `--help`, `-h` | Show usage |

### Modes

**Default - auto-fetch nonce (recommended)**
```cmd
RequestAADRefreshToken2.exe
```
Fetches a fresh nonce from AAD automatically using `POST /oauth2/token` with `grant_type=srv_challenge`, then requests the PRT cookie. No external tools required.

**With tenant ID**
```cmd
RequestAADRefreshToken2.exe -t yourtenant.onmicrosoft.com
```

**Manual nonce from roadrecon**
```cmd
roadrecon auth --prt-init -t <TenantId>
RequestAADRefreshToken2.exe --nonce AQABAAAAAAD...
```

**Full URL (PulseSecurity technique)**
```cmd
RequestAADRefreshToken2.exe "https://login.microsoftonline.com/...&sso_nonce=AQAB..."
```

**Legacy mode**
```cmd
RequestAADRefreshToken2.exe -legacy
```

---

## Example Output
<img width="1581" height="951" alt="image" src="https://github.com/user-attachments/assets/fad177c1-6fa7-47fc-b359-f295bb8e5894" />

## Using the Cookie

### Browser SSO Injection (Chrome)

1. Open Chrome DevTools (`F12`) on `https://login.microsoftonline.com`
2. Go to `Application > Cookies > https://login.microsoftonline.com`
3. Delete all existing cookies
4. Add a new cookie:
   - **Name:** `x-ms-RefreshTokenCredential`
   - **Value:** the `Data` field from the output
5. Refresh the page
<img width="1812" height="932" alt="image" src="https://github.com/user-attachments/assets/dc04fbad-53a5-4766-87c1-d0482f2ecc37" />


### Token Exchange via roadtx

```bash
roadtx auth --prt-cookie <DATA> -t <TenantId> -r msgraph
```

### Token Exchange - No External Dependencies

Use [Get-PRTToken.ps1](https://gist.github.com/Abdelhadi963/8a7be60ffa9ed2fd500292e134597430) to exchange the cookie for an MS Graph access token and connect without roadtx:

```powershell
.\Get-PRTToken.ps1 -PrtCookie "<DATA>" -TenantId "<TenantId>"
```

---

## Detection

When this tool executes, `MicrosoftAccountTokenProvider.dll` is loaded into the calling process. Defenders can baseline which processes normally load this DLL and alert on anomalies.

ETW provider `{05f02597-fe85-4e67-8542-69567ab8fd4f}` emits telemetry on `GetCookieInfoForUri` calls and can be monitored via process-level ETW tracing.

---

## Prerequisites Check

```cmd
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
|---|---|
| [RequestAADRefreshToken](https://github.com/leechristensen/RequestAADRefreshToken) | Original C# tool by Lee Christensen |
| [aad_prt_bof](https://github.com/wotwot563/aad_prt_bof) | BOF port for in-process execution via C2 |
| [ROADtools / roadtx](https://github.com/dirkjanm/ROADtools) | Token manipulation and tenant enumeration |
| [CS-Situational-Awareness-BOF](https://github.com/trustedsec/CS-Situational-Awareness-BOF) | AAD join state and WAM account enumeration BOFs |

---

## References

- [Microsoft Docs - Primary Refresh Token](https://learn.microsoft.com/en-us/entra/identity/devices/concept-primary-refresh-token)
- [Dirk-jan Mollema - Abusing Azure AD SSO with the Primary Refresh Token](https://dirkjanm.io/abusing-azure-ad-sso-with-the-primary-refresh-token/)
- [SpecterOps - Requesting Azure AD Tokens for Browser SSO](https://specterops.io/blog/2020/07/14/requesting-azure-ad-request-tokens-on-azure-ad-joined-machines-for-browser-sso/)
- [SpecterOps - An Operator's Guide to Device-Joined Hosts and the PRT Cookie](https://specterops.io/blog/2025/04/07/an-operators-guide-to-device-joined-hosts-and-the-prt-cookie/)
- [PulseSecurity - Primary Refresh Token Exploitation](https://pulsesecurity.co.nz/articles/exploiting-entraid-prt)

---

## Disclaimer

This tool is intended for authorized red team operations and security research only. Use only on systems you have explicit permission to test.
