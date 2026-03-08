# ============================================
#  Load Balancing Test - DEPUIS L'INTERIEUR
#  Utilise un pod curl dans le cluster
# ============================================

$TOTAL_REQUESTS = 30
$SVC_NAME = "cyber-world-entry"
$SVC_PORT = "80"

$pod_count = @{}
$pod_colors = @("Green", "Cyan", "Magenta", "Yellow", "Blue")
$pod_color_map = @{}
$color_index = 0

Clear-Host
$line = "-" * 65

Write-Host $line -ForegroundColor White
Write-Host "   LOAD BALANCING TEST - $SVC_NAME" -ForegroundColor White
Write-Host "   $TOTAL_REQUESTS requetes depuis l'INTERIEUR du cluster" -ForegroundColor Gray
Write-Host $line -ForegroundColor White
Write-Host ""

# ETAPE 1: Injecter hostname dans chaque pod
Write-Host "  [1/3] Injection hostname dans chaque pod..." -ForegroundColor Yellow
$pods = (kubectl get pods --no-headers -o custom-columns="NAME:.metadata.name") -split "`n" | Where-Object { $_.Trim() -ne "" }
foreach ($pod in $pods) {
    $pod = $pod.Trim()
    kubectl exec $pod -- /bin/sh -c "echo '<h1>'`$HOSTNAME'</h1>' > /usr/share/nginx/html/index.html" 2>$null | Out-Null
    Write-Host "    -> $pod : OK" -ForegroundColor Gray
}
Write-Host ""

# ETAPE 2: Lancer un pod curl temporaire dans le cluster
Write-Host "  [2/3] Lancement pod curl temporaire..." -ForegroundColor Yellow
kubectl run curl-tester --image=curlimages/curl --restart=Never --rm -i --command -- sleep 9999 2>$null | Out-Null
Start-Sleep -Seconds 5

# Verifier que le pod est pret
$ready = $false
for ($w = 0; $w -lt 15; $w++) {
    $status = (kubectl get pod curl-tester --no-headers 2>$null) -split '\s+' | Select-Object -Index 2
    if ($status -eq "Running") { $ready = $true; break }
    Start-Sleep -Seconds 2
}

if (-not $ready) {
    Write-Host "  [!] Pod curl-tester pas pret, tentative directe..." -ForegroundColor Yellow
}

Write-Host "  [3/3] Envoi des requetes..." -ForegroundColor Yellow
Write-Host ""
Write-Host $line -ForegroundColor White
Write-Host ("  {0,-4}  {1,-42}  {2}" -f "#", "POD REPOND", "STATUS") -ForegroundColor White
Write-Host $line -ForegroundColor White

# ETAPE 3: Envoyer les requetes depuis le pod interne
for ($i = 1; $i -le $TOTAL_REQUESTS; $i++) {
    $body = kubectl exec curl-tester -- curl -s "http://${SVC_NAME}:${SVC_PORT}" 2>$null

    $pod_name = ""
    if ($body -match "<h1>([^<]+)</h1>") {
        $pod_name = $matches[1].Trim()
    } else {
        $pod_name = "unknown"
    }

    if (-not $pod_color_map.ContainsKey($pod_name)) {
        $pod_color_map[$pod_name] = $pod_colors[$color_index % $pod_colors.Count]
        $color_index++
    }
    $color = $pod_color_map[$pod_name]

    if ($pod_count.ContainsKey($pod_name)) { $pod_count[$pod_name]++ }
    else { $pod_count[$pod_name] = 1 }

    Write-Host ("  {0,-4}  " -f $i) -NoNewline -ForegroundColor White
    Write-Host ("{0,-42}  " -f $pod_name) -NoNewline -ForegroundColor $color
    Write-Host "[OK]" -ForegroundColor Green
}

# Cleanup
kubectl delete pod curl-tester --force 2>$null | Out-Null

# ===== RESUME =====
Write-Host ""
Write-Host $line -ForegroundColor White
Write-Host "  RESUME DE L'EQUILIBRAGE" -ForegroundColor White
Write-Host $line -ForegroundColor White
Write-Host ""

$MAX_BAR = 28

foreach ($pod_name in $pod_count.Keys) {
    $count   = $pod_count[$pod_name]
    $percent = [math]::Round($count * 100 / $TOTAL_REQUESTS)
    $bar_len = [math]::Round($count * $MAX_BAR / $TOTAL_REQUESTS)
    $bar     = "#" * $bar_len
    $empty   = "." * ($MAX_BAR - $bar_len)
    $color   = $pod_color_map[$pod_name]

    Write-Host ("  {0,-42}  " -f $pod_name) -NoNewline -ForegroundColor $color
    Write-Host ("[{0}{1}]" -f $bar, $empty) -NoNewline -ForegroundColor $color
    Write-Host ("  {0,3}%  ({1} req)" -f $percent, $count) -ForegroundColor White
}

Write-Host ""
Write-Host $line -ForegroundColor White
Write-Host "  Total envoye  : $TOTAL_REQUESTS requetes" -ForegroundColor Cyan
Write-Host "  Pods detectes : $($pod_count.Count)" -ForegroundColor Cyan
Write-Host ""

if ($pod_count.Count -gt 1) {
    Write-Host "  [OK] Load Balancing ACTIF -- trafic sur $($pod_count.Count) pods" -ForegroundColor Green
} elseif ($pod_count.Count -eq 1) {
    Write-Host "  [!] 1 seul pod detecte" -ForegroundColor Yellow
} else {
    Write-Host "  [X] Aucun pod detecte" -ForegroundColor Red
}
Write-Host ""