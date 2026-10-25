param (
    [string]$ImagePath = "..\Brandings\Pics Tiles\Everyday Idioms Illustrated_ A Visual Guide.png",
    [int]$Columns = 5,
    [int]$Rows = 2
)

Add-Type -AssemblyName System.Runtime.WindowsRuntime
$asTaskGeneric = [System.WindowsRuntimeSystemExtensions].GetMethods() | ? { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' }

function AwaitOperation($op, $type) {
    $m = $asTaskGeneric.MakeGenericMethod($type)
    $t = $m.Invoke($null, @($op))
    $t.Wait()
    return $t.Result
}

[Windows.Security.Cryptography.CryptographicBuffer, Windows.Security.Cryptography, ContentType = WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType = WindowsRuntime] | Out-Null
[Windows.Media.Ocr.OcrEngine, Windows.Media.Ocr, ContentType = WindowsRuntime] | Out-Null
[Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
[Windows.Storage.FileAccessMode, Windows.Storage, ContentType = WindowsRuntime] | Out-Null

$fullPath = [System.IO.Path]::GetFullPath($ImagePath)
$fileOp = [Windows.Storage.StorageFile]::GetFileFromPathAsync($fullPath)
$file = AwaitOperation $fileOp ([Windows.Storage.StorageFile])

$streamOp = $file.OpenAsync([Windows.Storage.FileAccessMode]::Read)
$stream = AwaitOperation $streamOp ([Windows.Storage.Streams.IRandomAccessStream])

$decoderOp = [Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)
$decoder = AwaitOperation $decoderOp ([Windows.Graphics.Imaging.BitmapDecoder])

$bitmapOp = $decoder.GetSoftwareBitmapAsync()
$bitmap = AwaitOperation $bitmapOp ([Windows.Graphics.Imaging.SoftwareBitmap])

$imgW = $bitmap.PixelWidth
$imgH = $bitmap.PixelHeight

$engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
$ocrOp = $engine.RecognizeAsync($bitmap)
$ocrResult = AwaitOperation $ocrOp ([Windows.Media.Ocr.OcrResult])

$rowH = $imgH / $Rows
$colW = $imgW / $Columns

# Initialize result cards
$cardsList = @()
for ($i = 0; $i -lt ($Rows * $Columns); $i++) {
    $cardsList += [PSCustomObject]@{
        index = $i
        row = [Math]::Floor($i / $Columns)
        column = $i % $Columns
        titleLines = @()
        meaningLines = @()
    }
}

foreach ($line in $ocrResult.Lines) {
    $lineText = $line.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($lineText)) { continue }
    if ($lineText -match '^Meaning') { continue }
    if ($lineText.Length -eq 1 -and [char]::IsDigit($lineText[0])) { continue }

    # Find line bounding rect
    $firstWord = $line.Words[0].BoundingRect
    $lastWord = $line.Words[-1].BoundingRect
    $minX = $firstWord.X
    $maxX = $lastWord.X + $lastWord.Width
    $lineMidX = ($minX + $maxX) / 2.0
    $lineMidY = $firstWord.Y + ($firstWord.Height / 2.0)

    # Determine row
    $rIdx = [Math]::Floor($lineMidY / $rowH)
    if ($rIdx -lt 0) { $rIdx = 0 }
    if ($rIdx -ge $Rows) { $rIdx = $Rows - 1 }

    # Determine column by line midpoint
    $cIdx = [Math]::Floor($lineMidX / $colW)
    if ($cIdx -lt 0) { $cIdx = 0 }
    if ($cIdx -ge $Columns) { $cIdx = $Columns - 1 }

    $cardIdx = $rIdx * $Columns + $cIdx
    $headerMaxY = ($rIdx * $rowH) + ($rowH * 0.40)
    $meaningMinY = ($rIdx * $rowH) + ($rowH * 0.55)

    if ($lineMidY -lt $headerMaxY) {
        $cardsList[$cardIdx].titleLines += $lineText
    } elseif ($lineMidY -gt $meaningMinY) {
        $cardsList[$cardIdx].meaningLines += $lineText
    }
}

$finalCards = @()
foreach ($card in $cardsList) {
    $titleStr = ($card.titleLines -join " ").Trim()
    $meaningStr = ($card.meaningLines -join " ").Trim()
    $finalCards += [PSCustomObject]@{
        index = $card.index
        row = $card.row
        column = $card.column
        title = $titleStr
        meaning = $meaningStr
    }
}

$outputObj = [PSCustomObject]@{
    imageWidth = $imgW
    imageHeight = $imgH
    rows = $Rows
    columns = $Columns
    cards = $finalCards
}

$outputObj | ConvertTo-Json -Depth 4
