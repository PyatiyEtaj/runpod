# ai-ver-2

RunPod project for the standard PyTorch + Python Linux template. It handles two tasks:

1. Build a FLUX LoRA dataset with ComfyUI:
   - remove background;
   - resize/crop;
   - generate captions with JoyCaption;
   - save images and sidecar `.txt` captions.
2. Train a FLUX.1-dev LoRA with Kohya_ss.

Target hardware:

- GPU: RTX 5090 32 GB
- RAM: 60 GB
- Persistent storage: 200 GB

## Layout

```text
/workspace/ai-ver-2/
  configs/kohya/              # Kohya training configs
  datasets/raw/               # source images
  datasets/processed/         # ComfyUI output
  datasets/flux_lora/         # final image + .txt training dataset
  models/flux/                # FLUX, CLIP, T5, AE files
  models/joycaption/          # fancyfeast JoyCaption model
  models/rmbg/                # briaai RMBG-2.0 model
  outputs/lora/               # trained LoRA files
  outputs/logs/               # Kohya logs
  outputs/samples/            # training samples
  workflows/comfyui/          # ComfyUI workflow templates
```

External applications are expected beside the project:

```text
/workspace/ComfyUI
/workspace/kohya_ss
/workspace/venv-comfyui
/workspace/venv-dataset
/workspace/venv-kohya
```

## First Run On RunPod

Clone this repository into `/workspace/ai-ver-2`, then run:

```bash
cd /workspace/ai-ver-2
cp .env.example .env
bash scripts/setup_project.sh
bash scripts/bootstrap_runpod.sh
bash scripts/download_flux_dev.sh
bash scripts/download_hf_models.sh
```

`bootstrap_runpod.sh` clones ComfyUI and Kohya_ss and creates separate Python environments.
`download_flux_dev.sh` downloads FLUX.1-dev, text encoders, VAE, and installs ComfyUI model paths.
`download_hf_models.sh` downloads the selected dataset-pipeline models from Hugging Face.

No Docker build is required for the normal RunPod PyTorch template. The scripts install ComfyUI, Kohya_ss, Python environments, models, and local ComfyUI nodes on persistent storage.

## Required Models

FLUX.1-dev files are configured in `.env`:

```text
FLUX_DEV_REPO=black-forest-labs/FLUX.1-dev
FLUX_TEXT_ENCODERS_REPO=comfyanonymous/flux_text_encoders
FLUX_DEV_FILE=flux1-dev.safetensors
FLUX_AE_FILE=ae.safetensors
FLUX_CLIP_L_FILE=clip_l.safetensors
FLUX_T5XXL_FILE=t5xxl_fp16.safetensors
```

FLUX.1-dev is gated on Hugging Face. Accept the model license on Hugging Face, set `HF_TOKEN` in `.env`, then run:

```bash
bash scripts/download_flux_dev.sh
```

The files are downloaded to:

```text
models/flux/diffusion_models/flux1-dev.safetensors
models/flux/text_encoders/clip_l.safetensors
models/flux/text_encoders/t5xxl_fp16.safetensors
models/flux/vae/ae.safetensors
```

The same files are used by Kohya and ComfyUI.

## FLUX.1-dev In ComfyUI

ComfyUI is connected to project model storage through:

```text
configs/comfyui/extra_model_paths.yaml
```

Install or refresh it with:

```bash
bash scripts/install_comfyui_model_paths.sh
```

Then start ComfyUI:

```bash
bash scripts/start_comfyui.sh
```

In ComfyUI, FLUX files should be visible as:

```text
diffusion_models: flux1-dev.safetensors
text_encoders: clip_l.safetensors
text_encoders: t5xxl_fp16.safetensors
vae: ae.safetensors
```

Use this template as a reference workflow for a quick model test:

```text
workflows/comfyui/flux_dev_basic_generation.json
```

Dataset pipeline models are configured in `.env`:

```text
JOYCAPTION_REPO=fancyfeast/llama-joycaption-alpha-two-hf-llava
RMBG_REPO=briaai/RMBG-2.0
```

They are downloaded to:

```text
models/joycaption/llama-joycaption-alpha-two-hf-llava/
models/rmbg/RMBG-2.0/
```

## Dataset Processor

The dataset pipeline runs in a separate virtual environment:

```text
/workspace/venv-dataset
```

This keeps JoyCaption/RMBG/transformers dependencies out of ComfyUI and Kohya.
RMBG-2.0 requires `kornia`, which is installed only in this dataset environment.

Create or rebuild the dataset environment with:

```bash
bash scripts/setup_dataset_env.sh
```

Run the dataset processor with:

```bash
bash scripts/process_dataset.sh
```

Crop modes:

```bash
bash scripts/process_dataset.sh --crop-region full
bash scripts/process_dataset.sh --crop-region upper
bash scripts/process_dataset.sh --crop-region lower
```

Convenience wrappers:

```bash
bash scripts/process_dataset_full.sh
bash scripts/process_dataset_upper.sh
bash scripts/process_dataset_lower.sh
```

It does the full dataset pass:

- reads images from `datasets/raw`;
- removes background with `briaai/RMBG-2.0` for 80% of images;
- keeps background unchanged for 20% of images;
- resizes/crops to `1024x1024`;
- captions with `fancyfeast/llama-joycaption-alpha-two-hf-llava`;
- writes `.png + .txt` pairs to `datasets/processed`.

The same processing code is also available as a ComfyUI local custom node:

```text
AIVer2DatasetBuilder
```

That node is optional. Install it only if you explicitly want to run dataset processing inside ComfyUI:

```bash
bash scripts/install_comfyui_custom_nodes.sh
```

The recommended path is `bash scripts/process_dataset.sh`, because it keeps dataset dependencies separate from ComfyUI.

Open this workflow:

```text
workflows/comfyui/dataset_pipeline.json
```

No placeholder replacement is needed. The workflow uses the real node class:

```text
AIVer2DatasetBuilder
```

The default dataset mix is configured in the workflow:

```text
skip_background_removal_percent = 20.0
skip_background_removal_seed = 42
```

The selection is deterministic by filename and seed, so reruns keep the same images with background unless you change the seed.

## Dataset Preparation

Put source images into:

```text
datasets/raw/
```

Process the dataset:

```bash
cd /workspace/ai-ver-2
bash scripts/process_dataset.sh
```

It reads from `datasets/raw/` and writes into `datasets/processed/`.

Expected ComfyUI output:

```text
datasets/processed/
  0001.png
  0001.txt
  0002.png
  0002.txt
```

Sync processed files into the training dataset:

```bash
bash scripts/prepare_dataset.sh
```

Final training dataset:

```text
datasets/flux_lora/
  0001.png
  0001.txt
  0002.png
  0002.txt
```

## Train FLUX LoRA

Edit if needed:

```text
configs/kohya/flux_lora.toml
configs/kohya/sample_prompts.txt
```

Start training:

```bash
cd /workspace/ai-ver-2
bash scripts/train_flux_lora.sh
```

LoRA output:

```text
outputs/lora/
```

## Starting Parameters

The default config is conservative for 32 GB VRAM:

- `train_batch_size = 1`
- `gradient_accumulation_steps = 4`
- `network_dim = 32`
- `mixed_precision = "bf16"`
- `cache_latents = true`
- `cache_text_encoder_outputs = true`
- `gradient_checkpointing = true`

If VRAM is tight, reduce `network_dim` to `16` or disable sampling during training.

## Notes

- Keep raw images, processed datasets, model files, and LoRA outputs on persistent storage.
- Clean `cache/` when storage gets tight.
- Do not commit model files or datasets; `.gitignore` excludes them.

## Troubleshooting

If dependency versions got messy, do not keep repairing packages one by one. Rebuild the project virtual environments from scratch:

```bash
cd /workspace/ai-ver-2
bash scripts/rebuild_venvs_clean.sh
```

This deletes only:

```text
/workspace/venv-comfyui
/workspace/venv-dataset
/workspace/venv-kohya
```

It does not delete models, datasets, outputs, `/workspace/ComfyUI`, or `/workspace/kohya_ss`.

For L40S with driver `12040`, keep this in `.env`:

```text
PYTORCH_INDEX_URL=https://download.pytorch.org/whl/cu124
TORCH_VERSION=2.6.0
TORCHVISION_VERSION=0.21.0
TORCHAUDIO_VERSION=2.6.0
```

If dataset processing fails on RMBG with:

```text
Should have a `model_type` key in its config.json
```

update the project and rerun processing. `briaai/RMBG-2.0` has a config without `model_type`; the processor falls back from the local directory to `RMBG_REPO=briaai/RMBG-2.0` using `HF_TOKEN`.

If ComfyUI fails with:

```text
RuntimeError: The NVIDIA driver on your system is too old
found version 12040
```

the installed PyTorch CUDA build is newer than the host NVIDIA driver. Driver `12040` means the host supports CUDA 12.4, so use the default project setting:

```text
PYTORCH_INDEX_URL=https://download.pytorch.org/whl/cu124
```

If only the CUDA build is wrong, reinstall PyTorch in both project virtual environments:

```bash
cd /workspace/ai-ver-2
bash scripts/install_pytorch_cuda.sh
```

The script is idempotent: if the current PyTorch CUDA build already matches `PYTORCH_INDEX_URL`, it skips reinstalling `torch` and its NVIDIA dependencies.

If you move to a RunPod host with a newer CUDA 12.8 driver, you can change `PYTORCH_INDEX_URL` in `.env` to:

```text
https://download.pytorch.org/whl/cu128
```

If Kohya install fails with:

```text
sd-scripts does not appear to be a Python project
```

rerun the updated bootstrap script:

```bash
cd /workspace/ai-ver-2
bash scripts/bootstrap_runpod.sh
```

The script initializes Kohya submodules and filters the editable `./sd-scripts` requirement, then installs `sd-scripts` dependencies separately.

If Kohya install fails with:

```text
No matching distribution found for tensorflow==2.15.0.post1
```

rerun the updated bootstrap script. The project filters that pinned TensorFlow dependency because it is not available for Python 3.12 and is not required for the PyTorch FLUX LoRA path.

If Kohya install fails with:

```text
Multiple top-level packages discovered in a flat-layout
```

rerun the updated bootstrap script. The project skips editable installation of the Kohya repository root and runs Kohya scripts directly from `/workspace/kohya_ss`.

If pip prints dependency conflicts for `huggingface-hub` or `rich`, rerun the updated bootstrap script.

Kohya currently uses older `transformers`, so `venv-kohya` is kept on:

```text
huggingface-hub>=0.28.1,<1.0
rich>=13.8.0
```

ComfyUI may use newer `transformers`, so `venv-comfyui` is kept on:

```text
huggingface-hub>=1.5.0,<2.0
rich>=13.8.0
```

Dataset/JoyCaption uses `transformers 4.x`, so `venv-dataset` is kept on:

```text
huggingface-hub>=0.28.1,<1.0
transformers>=4.45,<5.0
```

For minor dependency drift, repair both project virtual environments:

```bash
bash scripts/repair_venvs.sh
```

The repair script also pins runtime packages that often get upgraded too far by PyTorch/Kohya installs:

```text
numpy<2.0.0
pillow<12.0
scipy<1.12
```

It removes `xformers` when it is incompatible with the installed PyTorch build. The project uses SDPA, so `xformers` is not required.

## Порядок Запуска Проекта

1. Подготовить проект на RunPod:

```bash
cd /workspace/ai-ver-2
cp .env.example .env
```

2. Вписать `HF_TOKEN` в `.env`. Токен нужен для gated модели `black-forest-labs/FLUX.1-dev`.

3. Установить ComfyUI, Kohya_ss, Python-зависимости и локальные ComfyUI nodes:

```bash
bash scripts/setup_project.sh
bash scripts/bootstrap_runpod.sh
```

`bootstrap_runpod.sh` does not reinstall dependencies if `/workspace/venv-comfyui`, `/workspace/venv-dataset`, and `/workspace/venv-kohya` already exist. To intentionally rebuild all virtual environments:

```bash
bash scripts/rebuild_venvs_clean.sh
```

4. Скачать модели:

```bash
bash scripts/download_flux_dev.sh
bash scripts/download_hf_models.sh
```

5. Положить исходные изображения в:

```text
/workspace/ai-ver-2/datasets/raw/
```

6. Обработать dataset:

```bash
bash scripts/process_dataset.sh
```

Он создаст обработанные изображения и captions в:

```text
/workspace/ai-ver-2/datasets/processed/
```

7. Синхронизировать готовый dataset для Kohya:

```bash
bash scripts/prepare_dataset.sh
```

8. Запустить обучение FLUX LoRA:

```bash
bash scripts/train_flux_lora.sh
```

Готовая LoRA будет сохранена в:

```text
/workspace/ai-ver-2/outputs/lora/
```

9. При необходимости запустить ComfyUI отдельно для проверки FLUX/generation:

```bash
bash scripts/start_comfyui.sh
```
