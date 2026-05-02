<#
.SYNOPSIS
    Fetches AC-Raiz ICP-Brasil v1..v10 certificates from ITI.

.DESCRIPTION
    Downloads each ACRaiz<NN>.crt from estrutura.iti.gov.br, converts to
    PEM if needed, and concatenates all certs into a single bundle file.

    Output: ac-raiz-icp-brasil.pem (the bundle)
            ac-raiz-icp-brasil-v<NN>.pem (individual files for audit)

.NOTES
    Refresh frequency: monthly (CI/cron). Bundle changes are rare but
    happen when ITI cross-signs a new V or revokes an old V.

    URLs are stable but may change — adjust $UrlPattern if necessary.
    Validate official source: https://estrutura.iti.gov.br/

.EXAMPLE
    pwsh -File AC-Raiz-ICP-Brasil-fetch.ps1
    pwsh -File AC-Raiz-ICP-Brasil-fetch.ps1 -OutputDir ./bundles -Verbose
#>

param(
    [string]$OutputDir = $PSScriptRoot,
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'

# Estrutura oficial das ACs Raiz ICP-Brasil — ajustar se ITI mudar URLs.
# Cada entry e (versao, URL do .crt). V1 e a primeira raiz (1999); V10 e a
# vigente em DOC-ICP-04 v8.x (2024+). Adicionar futuras versoes conforme ITI.
$AcRaizes = @(
    @{ V = 1;  Url = 'https://estrutura.iti.gov.br/repositorio/v1/ACRaiz_v1.crt'  },
    @{ V = 2;  Url = 'https://estrutura.iti.gov.br/repositorio/v2/ACRaiz_v2.crt'  },
    @{ V = 3;  Url = 'https://estrutura.iti.gov.br/repositorio/v3/ACRaiz_v3.crt'  },
    @{ V = 4;  Url = 'https://estrutura.iti.gov.br/repositorio/v4/ACRaiz_v4.crt'  },
    @{ V = 5;  Url = 'https://estrutura.iti.gov.br/repositorio/v5/ACRaiz_v5.crt'  },
    @{ V = 6;  Url = 'https://estrutura.iti.gov.br/repositorio/v6/ACRaiz_v6.crt'  },
    @{ V = 7;  Url = 'https://estrutura.iti.gov.br/repositorio/v7/ACRaiz_v7.crt'  },
    @{ V = 8;  Url = 'https://estrutura.iti.gov.br/repositorio/v8/ACRaiz_v8.crt'  },
    @{ V = 9;  Url = 'https://estrutura.iti.gov.br/repositorio/v9/ACRaiz_v9.crt'  },
    @{ V = 10; Url = 'https://estrutura.iti.gov.br/repositorio/v10/ACRaiz_v10.crt' }
)

function ConvertTo-Pem {
    param(
        [Parameter(Mandatory)][byte[]]$DerBytes,
        [Parameter(Mandatory)][string]$Subject
    )
    # Convert DER bytes to PEM (Base64 wrapped at 64 chars)
    $b64 = [Convert]::ToBase64String($DerBytes, 'InsertLineBreaks')
    # Header sub-comments help auditors identify which raiz this is.
    return @(
        "# Subject: $Subject"
        "-----BEGIN CERTIFICATE-----"
        $b64
        "-----END CERTIFICATE-----"
        ""
    ) -join "`n"
}

function Try-DownloadCert {
    param(
        [Parameter(Mandatory)]$Entry,
        [Parameter(Mandatory)]$OutputDir
    )
    $v = $Entry.V
    $url = $Entry.Url
    $individualPem = Join-Path $OutputDir "ac-raiz-icp-brasil-v$v.pem"

    Write-Host ("[V{0:D2}] Downloading {1}" -f $v, $url) -ForegroundColor Cyan

    try {
        $tmp = New-TemporaryFile
        Invoke-WebRequest -Uri $url -OutFile $tmp.FullName -UseBasicParsing -ErrorAction Stop
        $derBytes = [System.IO.File]::ReadAllBytes($tmp.FullName)
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "[V$v] Download falhou: $($_.Exception.Message)"
        return $null
    }

    # If file is already PEM (starts with '-----BEGIN'), keep as-is.
    $head = [System.Text.Encoding]::ASCII.GetString($derBytes, 0, [Math]::Min(40, $derBytes.Length))
    if ($head.StartsWith('-----BEGIN')) {
        $pem = [System.Text.Encoding]::ASCII.GetString($derBytes)
    } else {
        # DER -> PEM via X509Certificate2
        try {
            $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($derBytes)
            $pem = ConvertTo-Pem -DerBytes $derBytes -Subject $cert.Subject
            Write-Verbose "[V$v] Subject: $($cert.Subject)"
            Write-Verbose "[V$v] Thumbprint SHA1: $($cert.Thumbprint)"
            Write-Verbose "[V$v] NotAfter: $($cert.NotAfter)"
        } catch {
            Write-Warning "[V$v] Conversao DER->PEM falhou: $($_.Exception.Message)"
            return $null
        }
    }

    Set-Content -Path $individualPem -Value $pem -Encoding ASCII
    Write-Host ("[V{0:D2}] Salvou {1}" -f $v, $individualPem) -ForegroundColor Green
    return $pem
}

# --- Main ---

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$bundlePath = Join-Path $OutputDir 'ac-raiz-icp-brasil.pem'
$bundleHeader = @(
    "# AC-Raiz ICP-Brasil — bundle"
    "# Gerado por AC-Raiz-ICP-Brasil-fetch.ps1 em $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    "# Fonte: https://estrutura.iti.gov.br"
    "# Refresh policy: mensal (CI/cron); ad-hoc apos eventos ITI."
    "#"
    "# Uso (Pascal):"
    "#   var V: TX509ChainVerifier;"
    "#   V := TX509ChainVerifier.Create;"
    "#   V.LoadStoreFromPEM('bundles/ac-raiz-icp-brasil.pem');"
    ""
) -join "`n"

$bundleContent = [System.Text.StringBuilder]::new()
[void]$bundleContent.Append($bundleHeader)

$ok = 0
$fail = 0
foreach ($entry in $AcRaizes) {
    $pem = Try-DownloadCert -Entry $entry -OutputDir $OutputDir
    if ($null -ne $pem) {
        [void]$bundleContent.AppendLine("# AC-Raiz V$($entry.V)")
        [void]$bundleContent.AppendLine($pem.TrimEnd())
        [void]$bundleContent.AppendLine()
        $ok++
    } else {
        $fail++
    }
}

if ($ok -eq 0) {
    Write-Error "Nenhuma AC-Raiz baixada. Verificar URLs em \$AcRaizes."
    exit 1
}

Set-Content -Path $bundlePath -Value $bundleContent.ToString() -Encoding ASCII

Write-Host ""
Write-Host "================================================================"
Write-Host "Bundle gerado: $bundlePath" -ForegroundColor Yellow
Write-Host "ACs baixadas com sucesso: $ok"
if ($fail -gt 0) {
    Write-Host "ACs que falharam:        $fail" -ForegroundColor Red
}
Write-Host "================================================================"
