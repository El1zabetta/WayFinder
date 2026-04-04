"""
WayFinder 2.0 — Video Processing Pipeline
Extracts frames from uploaded video clips for RynnBrain 2B inference.
Optimized for real-time egocentric video at 2 FPS.
"""

import io
import logging
from typing import Optional

import av
import numpy as np
from PIL import Image

logger = logging.getLogger(__name__)

# Target dimensions for RynnBrain-2B (balances speed vs. accuracy)
TARGET_WIDTH = 560
TARGET_HEIGHT = 420
TARGET_FPS = 2


def extract_frames(
    video_bytes: bytes,
    target_fps: float = TARGET_FPS,
    max_frames: int = 16,
    width: int = TARGET_WIDTH,
    height: int = TARGET_HEIGHT,
) -> list[Image.Image]:
    """
    Decode video bytes and extract frames at target_fps.

    Args:
        video_bytes: Raw video content (mp4/webm/h264)
        target_fps: Sampling rate (2 FPS optimal for RynnBrain-2B)
        max_frames: Maximum frames to return
        width: Resize width
        height: Resize height

    Returns:
        List of PIL Images in RGB format, tagged with frame index.
    """
    try:
        container = av.open(io.BytesIO(video_bytes))
        video_stream = next(
            (s for s in container.streams if s.type == "video"), None
        )
        if video_stream is None:
            raise ValueError("No video stream found in uploaded file")

        src_fps = float(video_stream.average_rate or 30)
        frame_interval = max(1, int(src_fps / target_fps))

        frames: list[Image.Image] = []
        frame_count = 0

        for packet in container.demux(video_stream):
            for frame in packet.decode():
                if frame_count % frame_interval == 0:
                    img = frame.to_image()
                    img = img.convert("RGB")
                    # Using BILINEAR for speed over LANCZOS in real-time context
                    img = img.resize((width, height), Image.BILINEAR)
                    frames.append(img)
                    if len(frames) >= max_frames:
                        container.close()
                        return frames
                frame_count += 1

        container.close()
        logger.info(f"[VideoProc] Extracted {len(frames)} frames at {target_fps} FPS")
        return frames

    except Exception as e:
        logger.error(f"[VideoProc] Frame extraction failed: {e}")
        raise RuntimeError(f"Video processing error: {e}") from e


def extract_single_image(image_bytes: bytes) -> Image.Image:
    """Convert image bytes to PIL Image for single-frame analysis."""
    img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    img = img.resize((TARGET_WIDTH, TARGET_HEIGHT), Image.LANCZOS)
    return img


def frames_to_grid(frames: list[Image.Image], cols: int = 4) -> Image.Image:
    """
    Compose frames into a visual grid for debugging/logging.
    Not used in inference — only for development inspection.
    """
    rows = (len(frames) + cols - 1) // cols
    grid_w = cols * TARGET_WIDTH
    grid_h = rows * TARGET_HEIGHT
    grid = Image.new("RGB", (grid_w, grid_h), (20, 20, 20))
    for i, frame in enumerate(frames):
        col = i % cols
        row = i // cols
        grid.paste(frame, (col * TARGET_WIDTH, row * TARGET_HEIGHT))
    return grid
