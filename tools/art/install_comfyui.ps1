# Installs ComfyUI + SDXL for generating placeholder art previews.
#
# These previews are NOT shipped assets. They exist so Joao can look at a
# concrete image and say "more like this, less like that" before anyone --
# an artist or a shader -- commits real effort. Steam requires disclosing
# AI-generated content that ships, so anything from here either gets
# replaced or gets declared.
#
# Run from anywhere:  powershell -ExecutionPolicy Bypass -File tools\art\install_comfyui.ps1

$ErrorActionPreference = "Stop"
$Root = "C:\ComfyUI"

Write-Host "== Ghost Guild art preview setup ==" -ForegroundColor Cyan

# --- prerequisites -----------------------------------------------------------
$py = (Get-Command python -ErrorAction SilentlyContinue).Source
if (-not $py) { throw "python not found on PATH" }
$ver = (python --version 2>&1) -replace 'Python ',''
Write-Host "python $ver at $py"

$gpu = nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>$null
if (-not $gpu) { throw "nvidia-smi not found - no NVIDIA driver?" }
Write-Host "gpu $gpu"

# --- ComfyUI ------------------------------------------------------------------
if (Test-Path $Root) {
	Write-Host "ComfyUI already at $Root - pulling latest" -ForegroundColor Yellow
	git -C $Root pull --ff-only
} else {
	Write-Host "cloning ComfyUI to $Root"
	git clone --depth 1 https://github.com/comfyanonymous/ComfyUI $Root
}

# --- venv ---------------------------------------------------------------------
$venv = Join-Path $Root "venv"
if (-not (Test-Path $venv)) {
	Write-Host "creating venv"
	python -m venv $venv
}
$vpy = Join-Path $venv "Scripts\python.exe"

& $vpy -m pip install --upgrade pip --quiet

# --- PyTorch --------------------------------------------------------------
# The RTX 50-series is Blackwell (compute capability sm_120). Wheels built
# against CUDA 12.1 -- which is what nearly every guide still tells you to
# install -- have no sm_120 kernels and fail at the first generation with
# "no kernel image is available". cu128 is the floor for this card.
Write-Host "installing PyTorch (cu128 - required for Blackwell/RTX 50xx)" -ForegroundColor Cyan
& $vpy -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128

Write-Host "installing ComfyUI requirements"
& $vpy -m pip install -r (Join-Path $Root "requirements.txt")

# --- verify the GPU is actually usable ---------------------------------------
$probe = @'
import torch
print("torch", torch.__version__)
print("cuda available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("device:", torch.cuda.get_device_name(0))
    cap = torch.cuda.get_device_capability(0)
    print("compute capability: sm_%d%d" % cap)
    archs = torch.cuda.get_arch_list()
    print("built for:", archs)
    tag = "sm_%d%d" % cap
    if tag not in archs:
        print("WARNING: this torch has no kernels for", tag, "- generation will fail")
    else:
        # Prove it, rather than trusting the flag.
        x = torch.randn(2048, 2048, device="cuda")
        print("matmul ok:", float((x @ x).sum()) == float((x @ x).sum()))
'@
$probe | Out-File -FilePath (Join-Path $Root "probe.py") -Encoding utf8
Write-Host "verifying GPU" -ForegroundColor Cyan
& $vpy (Join-Path $Root "probe.py")

# --- model --------------------------------------------------------------------
$ckpt = Join-Path $Root "models\checkpoints"
New-Item -ItemType Directory -Force -Path $ckpt | Out-Null
$sdxl = Join-Path $ckpt "sd_xl_base_1.0.safetensors"
if (Test-Path $sdxl) {
	Write-Host "SDXL base already present"
} else {
	Write-Host "downloading SDXL base 1.0 (~6.9 GB, this is the slow part)" -ForegroundColor Cyan
	$url = "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors?download=true"
	curl.exe -L --progress-bar -o $sdxl $url
}

Write-Host ""
Write-Host "== done ==" -ForegroundColor Green
Write-Host "start it with:  tools\art\run_comfyui.ps1"
Write-Host "then open:      http://127.0.0.1:8188"
