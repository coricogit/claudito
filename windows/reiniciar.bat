@echo off
rem Reinicia Claudito (cierra la copia abierta y la vuelve a abrir sin consola).
cd /d "%~dp0"
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*claudito.pyw*' -and $_.Name -like 'python*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
timeout /t 1 >nul
start "" pyw -3 claudito.pyw
