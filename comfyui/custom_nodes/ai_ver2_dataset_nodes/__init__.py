import hashlib
import os
from pathlib import Path

import numpy as np
import torch
from PIL import Image, ImageOps


IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}


def _image_to_tensor(image):
    array = np.asarray(image).astype(np.float32) / 255.0
    return torch.from_numpy(array)[None,]


def _resize_crop_pad(image, width, height, resize_mode):
    image = ImageOps.exif_transpose(image).convert("RGBA")
    source_ratio = image.width / image.height
    target_ratio = width / height
    resize_mode = resize_mode.lower().strip()

    if resize_mode not in {"cover", "contain"}:
        raise ValueError(f"Unsupported resize_mode: {resize_mode}. Use cover or contain.")

    if (resize_mode == "cover" and source_ratio > target_ratio) or (
        resize_mode == "contain" and source_ratio < target_ratio
    ):
        new_height = height
        new_width = round(height * source_ratio)
    else:
        new_width = width
        new_height = round(width / source_ratio)

    image = image.resize((new_width, new_height), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))

    if resize_mode == "cover":
        left = max(0, (new_width - width) // 2)
        top = max(0, (new_height - height) // 2)
        image = image.crop((left, top, left + width, top + height))
        canvas.alpha_composite(image, ((width - image.width) // 2, (height - image.height) // 2))
    else:
        canvas.alpha_composite(image, ((width - image.width) // 2, (height - image.height) // 2))
    image = canvas

    return image


def _crop_region(image, crop_region):
    image = ImageOps.exif_transpose(image).convert("RGBA")
    crop_region = crop_region.lower().strip()

    if crop_region == "full":
        return image
    if crop_region == "upper":
        return image.crop((0, 0, image.width, image.height // 2))
    if crop_region == "lower":
        return image.crop((0, image.height // 2, image.width, image.height))

    raise ValueError(f"Unsupported crop_region: {crop_region}. Use full, upper, or lower.")


def _should_skip_background_removal(path, percent, seed):
    if percent <= 0:
        return False
    if percent >= 100:
        return True

    key = f"{seed}:{path.name}".encode("utf-8")
    digest = hashlib.sha256(key).digest()
    value = int.from_bytes(digest[:8], "big") % 10000
    return value < int(percent * 100)


class AIVer2DatasetBuilder:
    _rmbg_model = None
    _joy_model = None
    _joy_processor = None
    _realesrgan_model_path = None
    _realesrgan_upsampler = None

    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "input_dir": ("STRING", {"default": "/workspace/ai-ver-2/datasets/raw"}),
                "output_dir": ("STRING", {"default": "/workspace/ai-ver-2/datasets/processed"}),
                "rmbg_model_dir": ("STRING", {"default": "/workspace/ai-ver-2/models/rmbg/RMBG-2.0"}),
                "joycaption_model_dir": ("STRING", {"default": "/workspace/ai-ver-2/models/joycaption/llama-joycaption-alpha-two-hf-llava"}),
                "caption_prompt": ("STRING", {
                    "multiline": True,
                    "default": "Describe the subject accurately for FLUX LoRA training. Include visible clothing, style, pose, and important details. Do not mention removed background unless relevant.",
                }),
                "width": ("INT", {"default": 1024, "min": 256, "max": 2048, "step": 64}),
                "height": ("INT", {"default": 1024, "min": 256, "max": 2048, "step": 64}),
                "crop_region": (["full", "upper", "lower"], {"default": "full"}),
                "resize_mode": (["contain", "cover"], {"default": "contain"}),
                "enable_resize_crop": ("BOOLEAN", {"default": True}),
                "upscale_mode": (["none", "realesrgan_x4plus"], {"default": "none"}),
                "realesrgan_model_path": ("STRING", {"default": "/workspace/ai-ver-2/models/upscaler/RealESRGAN_x4plus.pth"}),
                "upscale_outscale": ("FLOAT", {"default": 4.0, "min": 1.0, "max": 4.0, "step": 0.25}),
                "output_prefix": ("STRING", {"default": ""}),
                "max_new_tokens": ("INT", {"default": 128, "min": 32, "max": 512, "step": 16}),
                "skip_background_removal_percent": ("FLOAT", {"default": 20.0, "min": 0.0, "max": 100.0, "step": 1.0}),
                "skip_background_removal_seed": ("INT", {"default": 42, "min": 0, "max": 2147483647, "step": 1}),
                "overwrite": ("BOOLEAN", {"default": False}),
            }
        }

    RETURN_TYPES = ("STRING",)
    RETURN_NAMES = ("summary",)
    FUNCTION = "build_dataset"
    CATEGORY = "ai-ver-2/dataset"

    def _load_rmbg(self, model_dir, device):
        if self.__class__._rmbg_model is None:
            from transformers import AutoModelForImageSegmentation

            try:
                model = AutoModelForImageSegmentation.from_pretrained(model_dir, trust_remote_code=True)
            except ValueError as exc:
                if "model_type" not in str(exc):
                    raise
                repo_id = os.environ.get("RMBG_REPO", "briaai/RMBG-2.0")
                token = os.environ.get("HF_TOKEN") or None
                model = AutoModelForImageSegmentation.from_pretrained(
                    repo_id,
                    trust_remote_code=True,
                    token=token,
                )
            model.to(device)
            model.eval()
            self.__class__._rmbg_model = model
        return self.__class__._rmbg_model

    def _load_joycaption(self, model_dir, device):
        if self.__class__._joy_model is None or self.__class__._joy_processor is None:
            from transformers import AutoProcessor, LlavaForConditionalGeneration

            processor = AutoProcessor.from_pretrained(model_dir, trust_remote_code=True)
            model = LlavaForConditionalGeneration.from_pretrained(
                model_dir,
                trust_remote_code=True,
                torch_dtype=torch.bfloat16 if device == "cuda" else torch.float32,
                device_map=0 if device == "cuda" else None,
            )
            if device != "cuda":
                model.to(device)
            model.eval()
            self.__class__._joy_processor = processor
            self.__class__._joy_model = model
        return self.__class__._joy_processor, self.__class__._joy_model

    def _remove_background(self, image, model_dir, device):
        from torchvision import transforms

        rgb = ImageOps.exif_transpose(image).convert("RGB")
        model = self._load_rmbg(model_dir, device)

        transform = transforms.Compose(
            [
                transforms.Resize((1024, 1024), interpolation=transforms.InterpolationMode.BILINEAR),
                transforms.ToTensor(),
                transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
            ]
        )

        tensor = transform(rgb).unsqueeze(0).to(device)
        with torch.inference_mode():
            pred = model(tensor)[-1].sigmoid().cpu()

        mask = pred[0].squeeze()
        mask = (mask - mask.min()) / (mask.max() - mask.min()).clamp(min=1e-6)
        mask_image = transforms.ToPILImage()(mask).resize(rgb.size, Image.Resampling.LANCZOS)

        rgba = rgb.convert("RGBA")
        rgba.putalpha(mask_image)
        return rgba

    def _load_realesrgan(self, model_path, device):
        model_path = str(model_path)
        if not Path(model_path).is_file():
            raise FileNotFoundError(f"RealESRGAN_x4plus model not found: {model_path}")

        if self.__class__._realesrgan_upsampler is not None and self.__class__._realesrgan_model_path == model_path:
            return self.__class__._realesrgan_upsampler

        import sys
        import types

        if "torchvision.transforms.functional_tensor" not in sys.modules:
            from torchvision.transforms.functional import rgb_to_grayscale

            functional_tensor = types.ModuleType("torchvision.transforms.functional_tensor")
            functional_tensor.rgb_to_grayscale = rgb_to_grayscale
            sys.modules["torchvision.transforms.functional_tensor"] = functional_tensor

        from basicsr.archs.rrdbnet_arch import RRDBNet
        from realesrgan import RealESRGANer

        model = RRDBNet(num_in_ch=3, num_out_ch=3, num_feat=64, num_block=23, num_grow_ch=32, scale=4)
        upsampler = RealESRGANer(
            scale=4,
            model_path=model_path,
            model=model,
            tile=0,
            tile_pad=10,
            pre_pad=0,
            half=device == "cuda",
            gpu_id=0 if device == "cuda" else None,
        )
        self.__class__._realesrgan_model_path = model_path
        self.__class__._realesrgan_upsampler = upsampler
        return upsampler

    def _upscale_realesrgan(self, image, model_path, outscale, device):
        upsampler = self._load_realesrgan(model_path, device)
        rgba = ImageOps.exif_transpose(image).convert("RGBA")
        bgr = np.asarray(rgba.convert("RGB"))[:, :, ::-1]
        output_bgr, _ = upsampler.enhance(bgr, outscale=outscale)
        output_rgb = output_bgr[:, :, ::-1]

        alpha = rgba.getchannel("A")
        alpha_size = (output_rgb.shape[1], output_rgb.shape[0])
        alpha = alpha.resize(alpha_size, Image.Resampling.LANCZOS)

        output = Image.fromarray(output_rgb).convert("RGBA")
        output.putalpha(alpha)
        return output

    def _caption(self, image, model_dir, prompt, max_new_tokens, device):
        processor, model = self._load_joycaption(model_dir, device)
        rgb = image.convert("RGB")

        if hasattr(processor, "apply_chat_template"):
            messages = [
                {
                    "role": "system",
                    "content": "You are a helpful image captioner.",
                },
                {
                    "role": "user",
                    "content": prompt,
                }
            ]
            text = processor.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
        else:
            text = prompt

        inputs = processor(text=[text], images=[rgb], return_tensors="pt")
        inputs = {key: value.to(model.device) if hasattr(value, "to") else value for key, value in inputs.items()}
        if "pixel_values" in inputs and device == "cuda":
            inputs["pixel_values"] = inputs["pixel_values"].to(torch.bfloat16)

        with torch.inference_mode():
            output_ids = model.generate(
                **inputs,
                max_new_tokens=max_new_tokens,
                do_sample=True,
                suppress_tokens=None,
                use_cache=True,
                temperature=0.6,
                top_k=None,
                top_p=0.9,
            )[0]

        if "input_ids" in inputs:
            output_ids = output_ids[inputs["input_ids"].shape[1]:]
        caption = processor.tokenizer.decode(
            output_ids,
            skip_special_tokens=True,
            clean_up_tokenization_spaces=False,
        ).strip()
        return " ".join(caption.split())

    def build_dataset(
        self,
        input_dir,
        output_dir,
        rmbg_model_dir,
        joycaption_model_dir,
        caption_prompt,
        width,
        height,
        crop_region,
        resize_mode,
        enable_resize_crop,
        upscale_mode,
        realesrgan_model_path,
        upscale_outscale,
        output_prefix,
        max_new_tokens,
        skip_background_removal_percent,
        skip_background_removal_seed,
        overwrite,
    ):
        input_path = Path(input_dir)
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)

        if not input_path.exists():
            raise FileNotFoundError(f"Input directory does not exist: {input_path}")

        images = sorted(path for path in input_path.iterdir() if path.suffix.lower() in IMAGE_EXTENSIONS)
        if not images:
            return (f"No images found in {input_path}",)

        device = "cuda" if torch.cuda.is_available() else "cpu"
        processed = 0
        skipped = 0
        background_removed = 0
        background_kept = 0
        upscaled = 0
        output_prefix = str(output_prefix or "")

        for source in images:
            stem = f"{output_prefix}{source.stem}"
            image_out = output_path / f"{stem}.png"
            caption_out = output_path / f"{stem}.txt"

            if not overwrite and image_out.exists() and caption_out.exists():
                skipped += 1
                continue

            image = Image.open(source)
            if enable_resize_crop:
                image = _crop_region(image, crop_region)
            else:
                image = ImageOps.exif_transpose(image).convert("RGBA")

            if _should_skip_background_removal(source, skip_background_removal_percent, skip_background_removal_seed):
                image = ImageOps.exif_transpose(image).convert("RGBA")
                background_kept += 1
            else:
                image = self._remove_background(image, rmbg_model_dir, device)
                background_removed += 1

            if upscale_mode == "realesrgan_x4plus":
                image = self._upscale_realesrgan(image, realesrgan_model_path, upscale_outscale, device)
                upscaled += 1
            elif upscale_mode != "none":
                raise ValueError(f"Unsupported upscale_mode: {upscale_mode}. Use none or realesrgan_x4plus.")

            if enable_resize_crop:
                image = _resize_crop_pad(image, width, height, resize_mode)
            caption = self._caption(image, joycaption_model_dir, caption_prompt, max_new_tokens, device)

            image.save(image_out)
            caption_out.write_text(caption + "\n", encoding="utf-8")
            processed += 1

        return (
            f"Processed {processed} images, skipped {skipped}. "
            f"Background removed: {background_removed}. "
            f"Background kept: {background_kept}. "
            f"Upscaled: {upscaled}. "
            f"Output: {output_path}",
        )


NODE_CLASS_MAPPINGS = {
    "AIVer2DatasetBuilder": AIVer2DatasetBuilder,
}

NODE_DISPLAY_NAME_MAPPINGS = {
    "AIVer2DatasetBuilder": "AI Ver 2 Dataset Builder",
}
