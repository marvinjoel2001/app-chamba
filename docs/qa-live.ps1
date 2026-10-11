param([ValidateSet('inspect', 'fixed', 'hourly', 'cancel', 'review')][string]$Scenario = 'inspect')
$ErrorActionPreference = 'Stop'
$taskAdb = Join-Path $env:LOCALAPPDATA 'Android/Sdk/platform-tools/adb.exe'
$taskBase = 'https://web-production-f0db6d.up.railway.app/api'

function Read-QASession([string]$Serial) {
    $taskRaw = & $taskAdb -s $Serial shell run-as com.chambatrabajo.app cat shared_prefs/FlutterSharedPreferences.xml
    if ($LASTEXITCODE -ne 0) { throw ('Session unavailable on ' + $Serial) }
    $taskXml = [xml]($taskRaw -join "`n")
    $taskToken = ($taskXml.map.string | Where-Object name -eq 'flutter.session_access_token').'#text'
    $taskUserRaw = ($taskXml.map.string | Where-Object name -eq 'flutter.session_user').'#text'
    if (!$taskToken -or !$taskUserRaw) { throw ('Login required on ' + $Serial) }
    [pscustomobject]@{ Serial = $Serial; Token = $taskToken; User = ($taskUserRaw | ConvertFrom-Json) }
}

function Invoke-QAApi($Session, [string]$Method, [string]$Path, $Body = $null) {
    $taskParams = @{
        Uri = $taskBase + $Path; Method = $Method; TimeoutSec = 30
        Headers = @{ Authorization = 'Bearer ' + $Session.Token }
        ContentType = 'application/json'
    }
    if ($null -ne $Body) { $taskParams.Body = $Body | ConvertTo-Json -Depth 10 -Compress }
    try { Invoke-RestMethod @taskParams }
    catch {
        # Never print request headers, session XML, tokens, or personal account data.
        $taskStatus = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 'network' }
        throw ("QA API failed: $Method $Path ($taskStatus)")
    }
}

$taskSessions = @((Read-QASession 'emulator-5554'), (Read-QASession 'emulator-5556'))
$taskClient = $taskSessions | Where-Object { $_.User.type -eq 'client' } | Select-Object -First 1
$taskWorker = $taskSessions | Where-Object { $_.User.type -eq 'worker' } | Select-Object -First 1
if (!$taskClient -or !$taskWorker) { throw 'One client and one worker session are required' }
Write-Output ('Client: ' + $taskClient.Serial + '; worker: ' + $taskWorker.Serial)

$taskSkills = Invoke-QAApi $taskWorker GET ('/mobile/worker/skills?workerUserId=' + $taskWorker.User.id)
$taskHistory = Invoke-QAApi $taskWorker GET ('/mobile/worker/history?workerUserId=' + $taskWorker.User.id)
$taskMessages = Invoke-QAApi $taskClient GET ('/mobile/messages?userId=' + $taskClient.User.id)
$taskStatus = Invoke-QAApi $taskClient GET ('/mobile/request-status?clientUserId=' + $taskClient.User.id)
Write-Output ('Read checks OK; skills=' + @($taskSkills.skills).Count + '; history=' + @($taskHistory.jobs).Count)
$taskRejected = @($taskHistory.jobs | Where-Object { $_.requestStatus -eq 'completed' -and $_.offerStatus -ne 'accepted' })
Write-Output ('Completed history rows excluded from wallet=' + $taskRejected.Count)
if ($Scenario -eq 'inspect') { exit }
if ($Scenario -eq 'review') {
    $taskReviewJob = $taskHistory.jobs | Where-Object {
        $_.title -like 'QA Chamba*' -and $_.requestStatus -eq 'completed' -and
        $_.offerStatus -eq 'accepted' -and $_.client.id -eq $taskClient.User.id
    } | Select-Object -First 1
    if (!$taskReviewJob) { throw 'No completed QA work belongs to these accounts' }
    $taskReviewBody = @{ requestId = $taskReviewJob.requestId; workerUserId = $taskWorker.User.id;
        clientUserId = $taskClient.User.id; stars = 5; comment = 'Calificacion QA de prueba autorizada' }
    $taskReview = Invoke-QAApi $taskClient POST '/mobile/reviews' $taskReviewBody
    $taskDuplicate = Invoke-QAApi $taskClient POST '/mobile/reviews' $taskReviewBody
    if (!$taskDuplicate.alreadyReviewed) { throw 'Duplicate review was not suppressed' }
    Write-Output 'Review saved; duplicate submission ignored OK'
    exit
}

if ($taskStatus.request -and $taskStatus.request.status -in @('pending', 'searching', 'negotiating', 'assigned')) {
    throw 'Client already has an active request; no existing work was changed'
}
if (!$taskSkills.skills -or @($taskSkills.skills).Count -eq 0) { throw 'Worker has no skills for this test' }
$taskCategory = [string]$taskSkills.skills[0]
$taskExplore = Invoke-QAApi $taskClient GET ('/mobile/explore?userId=' + $taskClient.User.id + '&latitude=0&longitude=0&radiusKm=25000')
$taskLocation = $taskExplore.nearbyWorkers | Where-Object id -eq $taskWorker.User.id | Select-Object -First 1
if (!$taskLocation -and $null -ne $taskExplore.user.currentLatitude -and $null -ne $taskExplore.user.currentLongitude) {
    $taskLocation = [pscustomobject]@{
        latitude = $taskExplore.user.currentLatitude
        longitude = $taskExplore.user.currentLongitude
    }
}
if (@($taskHistory.jobs | Where-Object { $_.requestStatus -eq 'assigned' -and $_.offerStatus -eq 'accepted' }).Count -gt 0) {
    throw 'Worker already has assigned work; no existing work was changed'
}
if ($null -eq $taskLocation.latitude -or $null -eq $taskLocation.longitude) {
    # Synthetic point for API contract checks, without changing saved user GPS.
    $taskLocation = [pscustomobject]@{ latitude = 0; longitude = 0 }
    Write-Output 'Synthetic QA request location; GPS discovery is not covered by this API flow'
}
$taskRequestBody = @{
    clientUserId = $taskClient.User.id; title = 'QA Chamba - prueba precio cerrado'
    description = 'Prueba QA autorizada de solicitud y oferta. No es un servicio real.'
    category = $taskCategory; budget = 100; priceType = 'fixed'; paymentMethod = 'Efectivo'
    address = 'Ubicacion de prueba QA'; latitude = $taskLocation.latitude; longitude = $taskLocation.longitude
    modality = 'fixed'
}
if ($Scenario -eq 'hourly') {
    $taskRequestBody.title = 'QA Chamba - prueba por hora'
    $taskRequestBody.modality = 'hourly'; $taskRequestBody.priceType = 'hour'
    $taskRequestBody.estimatedHours = 2; $taskRequestBody.hourlyRate = 20
    $taskRequestBody.budget = 40
}
if ($Scenario -eq 'cancel') { $taskRequestBody.title = 'QA Chamba - prueba cancelacion' }
$taskCreated = Invoke-QAApi $taskClient POST '/mobile/requests' $taskRequestBody
$taskRequestId = $taskCreated.request.id
if (!$taskRequestId) { throw 'Request response missing id' }
Write-Output ('QA request created: ' + $taskRequestId)
$taskCompleted = $false
try {
    $taskOffer = Invoke-QAApi $taskWorker POST '/mobile/offers/counter' @{
        requestId = $taskRequestId; workerUserId = $taskWorker.User.id; amount = $taskRequestBody.budget
        message = 'Oferta QA para prueba autorizada'
    }
    $taskOfferId = $taskOffer.offer.id
    if (!$taskOfferId) { throw 'Offer response missing id' }
    $taskAccepted = Invoke-QAApi $taskClient POST '/mobile/offers/accept' @{
        offerId = $taskOfferId; clientUserId = $taskClient.User.id
    }
    Write-Output 'Offer accepted OK'
    $null = Invoke-QAApi $taskWorker POST '/mobile/tracking/worker-arrived' @{
        requestId = $taskRequestId; workerUserId = $taskWorker.User.id
    }
    $null = Invoke-QAApi $taskClient POST '/mobile/tracking/client-confirm' @{
        requestId = $taskRequestId; clientUserId = $taskClient.User.id
    }
    $taskTracking = Invoke-QAApi $taskClient GET ('/mobile/tracking?requestId=' + $taskRequestId)
    Write-Output 'Arrival and tracking checks OK'
    if ($Scenario -eq 'hourly') {
        for ($taskCycle = 0; $taskCycle -lt 2; $taskCycle++) {
            $null = Invoke-QAApi $taskClient POST '/mobile/tracking/clock' @{ requestId = $taskRequestId; paused = $true }
            $taskPaused = Invoke-QAApi $taskClient GET ('/mobile/tracking?requestId=' + $taskRequestId)
            Start-Sleep -Milliseconds 1200
            $taskStillPaused = Invoke-QAApi $taskClient GET ('/mobile/tracking?requestId=' + $taskRequestId)
            if (!$taskStillPaused.workPaused -or $taskPaused.workElapsedSeconds -ne $taskStillPaused.workElapsedSeconds) {
                throw 'Hourly clock advanced while paused'
            }
            $null = Invoke-QAApi $taskClient POST '/mobile/tracking/clock' @{ requestId = $taskRequestId; paused = $false }
        }
        Write-Output 'Two pause/resume cycles OK; paused time excluded'
    }
    if ($Scenario -eq 'cancel') {
        $null = Invoke-QAApi $taskClient POST '/mobile/tracking/cancel' @{ requestId = $taskRequestId; userId = $taskClient.User.id }
        $taskCompleted = $true
        $taskRejectedCompletion = $false
        try {
            $null = Invoke-QAApi $taskWorker POST '/mobile/tracking/complete' @{ requestId = $taskRequestId; workerUserId = $taskWorker.User.id }
        } catch {
            if ($_.Exception.Message -notmatch '\(400\)') { throw }
            $taskRejectedCompletion = $true
        }
        if (!$taskRejectedCompletion) { throw 'Cancelled work incorrectly allowed completion' }
        $taskCancelled = Invoke-QAApi $taskClient GET ('/mobile/tracking?requestId=' + $taskRequestId)
        if ($taskCancelled.status -ne 'cancelled') { throw 'Cancelled status was not preserved' }
        Write-Output 'Cancellation OK; completing cancelled work rejected with HTTP 400'
        exit
    }
    $taskCompletion = Invoke-QAApi $taskWorker POST '/mobile/tracking/complete' @{
        requestId = $taskRequestId; workerUserId = $taskWorker.User.id
    }
    $taskCompleted = $true
    $taskFinal = Invoke-QAApi $taskClient GET ('/mobile/request-status?requestId=' + $taskRequestId + '&clientUserId=' + $taskClient.User.id)
    if ($taskFinal.request.status -ne 'completed') { throw 'Final status is not completed' }
    $taskFinalHistory = Invoke-QAApi $taskWorker GET ('/mobile/worker/history?workerUserId=' + $taskWorker.User.id)
    $taskRow = $taskFinalHistory.jobs | Where-Object requestId -eq $taskRequestId | Select-Object -First 1
    if ($taskRow.offerStatus -ne 'accepted' -or $taskRow.requestStatus -ne 'completed' -or $taskRow.amount -ne $taskCompletion.amount) {
        throw 'Wallet/history amount or statuses mismatch'
    }
    if ($Scenario -eq 'hourly') {
        $taskEndClock = Invoke-QAApi $taskClient GET ('/mobile/tracking?requestId=' + $taskRequestId)
        $taskExpectedAmount = [Math]::Round(20 * $taskEndClock.workElapsedSeconds / 3600, 2)
        if ([Math]::Abs($taskRow.amount - $taskExpectedAmount) -gt 0.01) { throw 'Hourly settlement does not match effective time' }
    } elseif ($taskRow.amount -ne 100) { throw 'Fixed-price settlement mismatch' }
    Write-Output ("$Scenario API flow OK: completed, accepted offer, amount=" + $taskRow.amount + '. No card charge performed.')
} finally {
    if (!$taskCompleted) {
        $null = Invoke-QAApi $taskClient POST '/mobile/tracking/cancel' @{
            requestId = $taskRequestId; userId = $taskClient.User.id
        }
        Write-Output 'Incomplete QA request cancelled'
    }
}
