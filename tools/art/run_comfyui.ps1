# Starts ComfyUI. Open http://127.0.0.1:8188 once it says "To see the GUI go to".
$Root = "C:\ComfyUI"
if (-not (Test-Path $Root)) { throw "ComfyUI not installed - run tools\art\install_comfyui.ps1 first" }
& (Join-Path $Root "venv\Scripts\python.exe") (Join-Path $Root "main.py") --preview-method auto
