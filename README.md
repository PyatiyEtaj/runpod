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

`bootstrap_runpod.sh` clones ComfyUI and Kohya_ss and installs their Python dependencies.
It also installs the local ComfyUI node pack from `comfyui/custom_nodes/ai_ver2_dataset_nodes`.
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

## Dataset ComfyUI Node

The dataset pipeline uses a local project node:

```text
AIVer2DatasetBuilder
```

It is installed by:

```bash
bash scripts/install_comfyui_custom_nodes.sh
```

The node does the full dataset pass:

- reads images from `datasets/raw`;
- removes background with `briaai/RMBG-2.0` for 80% of images;
- keeps background unchanged for 20% of images;
- resizes/crops to `1024x1024`;
- captions with `fancyfeast/llama-joycaption-alpha-two-hf-llava`;
- writes `.png + .txt` pairs to `datasets/processed`.

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

Start ComfyUI:

```bash
cd /workspace/ai-ver-2
bash scripts/start_comfyui.sh
```

Open RunPod port `8188`, load the workflow template, and process the images.
Run the `AI Ver 2 Dataset Builder` node. It reads from `datasets/raw/` and writes into `datasets/processed/`.

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

If pip prints dependency conflicts for `huggingface-hub` or `rich`, rerun the updated bootstrap script. It finishes Kohya installation by upgrading:

```text
huggingface-hub>=0.28.1,<1.0
rich>=13.8.0
```

For the ComfyUI environment only, run:

```bash
source /workspace/venv-comfyui/bin/activate
pip install --upgrade "huggingface-hub>=0.28.1,<1.0" "rich>=13.8.0"
deactivate
```

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

4. Скачать модели:

```bash
bash scripts/download_flux_dev.sh
bash scripts/download_hf_models.sh
```

5. Запустить ComfyUI:

```bash
bash scripts/start_comfyui.sh
```

6. Открыть RunPod port `8188`, загрузить workflow:

```text
/workspace/ai-ver-2/workflows/comfyui/dataset_pipeline.json
```

7. Положить исходные изображения в:

```text
/workspace/ai-ver-2/datasets/raw/
```

8. В ComfyUI запустить node:

```text
AI Ver 2 Dataset Builder
```

Он создаст обработанные изображения и captions в:

```text
/workspace/ai-ver-2/datasets/processed/
```

9. Синхронизировать готовый dataset для Kohya:

```bash
bash scripts/prepare_dataset.sh
```

10. Запустить обучение FLUX LoRA:

```bash
bash scripts/train_flux_lora.sh
```

Готовая LoRA будет сохранена в:

```text
/workspace/ai-ver-2/outputs/lora/
```
