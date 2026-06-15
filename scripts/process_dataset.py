import argparse
import importlib.util
from pathlib import Path


def load_dataset_builder(project_dir):
    node_path = Path(project_dir) / "comfyui" / "custom_nodes" / "ai_ver2_dataset_nodes" / "__init__.py"
    spec = importlib.util.spec_from_file_location("ai_ver2_dataset_nodes", node_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.AIVer2DatasetBuilder


def main():
    parser = argparse.ArgumentParser(description="Build FLUX LoRA dataset with RMBG-2.0 and JoyCaption.")
    parser.add_argument("--project-dir", default="/workspace/ai-ver-2")
    parser.add_argument("--input-dir", default="/workspace/ai-ver-2/datasets/raw")
    parser.add_argument("--output-dir", default="/workspace/ai-ver-2/datasets/processed")
    parser.add_argument("--rmbg-model-dir", default="/workspace/ai-ver-2/models/rmbg/RMBG-2.0")
    parser.add_argument(
        "--joycaption-model-dir",
        default="/workspace/ai-ver-2/models/joycaption/llama-joycaption-alpha-two-hf-llava",
    )
    parser.add_argument(
        "--caption-prompt",
        default=(
            "Describe the subject accurately for FLUX LoRA training. Include visible clothing, "
            "style, pose, and important details. Do not mention removed background unless relevant."
        ),
    )
    parser.add_argument("--width", type=int, default=1024)
    parser.add_argument("--height", type=int, default=1024)
    parser.add_argument("--max-new-tokens", type=int, default=128)
    parser.add_argument("--skip-background-removal-percent", type=float, default=20.0)
    parser.add_argument("--skip-background-removal-seed", type=int, default=42)
    parser.add_argument("--overwrite", action="store_true")
    args = parser.parse_args()

    builder_cls = load_dataset_builder(args.project_dir)
    builder = builder_cls()
    summary = builder.build_dataset(
        input_dir=args.input_dir,
        output_dir=args.output_dir,
        rmbg_model_dir=args.rmbg_model_dir,
        joycaption_model_dir=args.joycaption_model_dir,
        caption_prompt=args.caption_prompt,
        width=args.width,
        height=args.height,
        max_new_tokens=args.max_new_tokens,
        skip_background_removal_percent=args.skip_background_removal_percent,
        skip_background_removal_seed=args.skip_background_removal_seed,
        overwrite=args.overwrite,
    )
    print(summary[0])


if __name__ == "__main__":
    main()
